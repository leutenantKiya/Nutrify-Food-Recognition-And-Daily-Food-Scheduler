"""
Pipeline inferensi NutriFile dari ujung ke ujung.

Alur:
    gambar
      -> detektor YOLOv8-seg "produce" (biner, polygon mask per-instance)
      -> untuk setiap area yang terdeteksi:
            crop ROI -> klasifier bahan -> top-3 (kelas, prob)
                     -> klasifier hidangan -> top-3 (kelas, prob)
                     -> router pilih label kanonik
      -> estimasi porsi per deteksi (area mask * densitas)
      -> agregasi nutrisi
      -> rekomendasi + penjelasan
"""

from __future__ import annotations

from dataclasses import dataclass, field
from pathlib import Path
from typing import List, Optional, Sequence

import numpy as np

from . import config
from . import nutrition
from . import ontology
from . import portion as portion_mod
from . import classifier as cls_mod
from . import recommend as rec_mod
from . import explain as exp_mod


# ----------------------------------------------------------------------
# Lazy imports
# ----------------------------------------------------------------------

def _cv2():
    import cv2  # noqa: WPS433
    return cv2


def _yolo():
    from ultralytics import YOLO  # noqa: WPS433
    return YOLO


# ----------------------------------------------------------------------
# Complex-dish -> simple-ingredient fallback table.
#
# Used by _route_label to detect cases where the dish classifier picks a
# "complex dish that has a plain-ingredient alternative" (e.g. fried_rice
# while looking at plain steamed rice). When the ingredient classifier also
# sees the base ingredient with MODEST confidence (0.15-0.50), we override
# to the simpler interpretation to avoid overestimating calories.
# ----------------------------------------------------------------------
DISH_TO_INGREDIENT_FALLBACK = {
    # Rice family
    "fried_rice": "rice", "risotto": "rice",
    "paella": "rice", "bibimbap": "rice",
    # Bread family
    "garlic_bread": "bread", "french_toast": "bread",
    "bread_pudding": "bread",
    # Egg family
    "omelette": "egg", "eggs_benedict": "egg",
    "deviled_eggs": "egg", "huevos_rancheros": "egg",
    # Chicken family
    "chicken_curry": "chicken", "chicken_wings": "chicken",
    "chicken_quesadilla": "chicken",
    # Potato family
    "french_fries": "potato", "poutine": "potato",
    # Beef family
    "beef_carpaccio": "beef", "beef_tartare": "beef",
    "filet_mignon": "beef", "prime_rib": "beef",
    # Fish family
    "grilled_salmon": "fish", "sashimi": "fish",
    # Salad-style with one dominant veg
    "caprese_salad": "tomato",
}

# Decision thresholds for the family guard
SIMPLE_INGREDIENT_MIN = 0.15
SIMPLE_INGREDIENT_MAX = 0.50

# Reject regions where both heads are unconfident (probably not food at all)
UNKNOWN_REJECT_FLOOR = 0.30


# ----------------------------------------------------------------------
# COCO ensemble: stock yolov8s-seg.pt already knows several food classes.
# Running it alongside the produce detector recovers prepared dishes
# (pizza, donut, cake, hot_dog, sandwich) that the PackEat-trained produce
# detector completely misses.
# ----------------------------------------------------------------------
COCO_FOOD_CLASSES = {
    46: "banana", 47: "apple", 48: "sandwich", 49: "orange",
    50: "broccoli", 51: "carrot", 52: "hot_dog", 53: "pizza",
    54: "donut", 55: "cake",
}

# Map COCO label -> key in nutrition DB
COCO_TO_NUTRITION_KEY = {
    "banana": "banana", "apple": "apple",
    "sandwich": "club_sandwich", "orange": "lemon",
    "broccoli": "broccoli", "carrot": "carrot",
    "hot_dog": "hot_dog", "pizza": "pizza",
    "donut": "donuts", "cake": "chocolate_cake",
}

COCO_CONF_THRESHOLD = 0.25
COCO_IOU_THRESHOLD = 0.55
COCO_VS_PRODUCE_CONTAINMENT = 0.50
COCO_VS_PRODUCE_IOU = 0.40


# ----------------------------------------------------------------------
# Detection result dataclasses
# ----------------------------------------------------------------------

@dataclass
class Detection:
    bbox_xyxy: List[float]             # absolute pixel coordinates
    score: float
    mask_area_ratio: float             # 0..1, mask coverage of full image
    polygon_xy_norm: List[List[float]] # polygon coords in 0..1

    # filled in later
    label: Optional[str] = None
    label_source: Optional[str] = None  # "ingredient" | "dish"
    ingredient_top: List[tuple] = field(default_factory=list)  # [(name, prob), ...]
    dish_top:       List[tuple] = field(default_factory=list)
    portion: Optional[dict] = None
    nutrition: Optional[dict] = None

    def to_dict(self) -> dict:
        return {
            "bbox_xyxy": [round(v, 2) for v in self.bbox_xyxy],
            "score": round(self.score, 4),
            "mask_area_ratio": round(self.mask_area_ratio, 4),
            "label": self.label,
            "label_source": self.label_source,
            "ingredient_top": [(n, round(p, 4)) for n, p in self.ingredient_top],
            "dish_top": [(n, round(p, 4)) for n, p in self.dish_top],
            "portion": self.portion,
            "nutrition": self.nutrition,
        }


@dataclass
class PipelineResult:
    image_shape: tuple
    detections: List[Detection]
    aggregated_nutrition: dict
    recommendations: List[dict]
    explanation: str

    def to_dict(self) -> dict:
        return {
            "image_shape": list(self.image_shape),
            "detections": [d.to_dict() for d in self.detections],
            "aggregated_nutrition": self.aggregated_nutrition,
            "recommendations": self.recommendations,
            "explanation": self.explanation,
        }


# ----------------------------------------------------------------------
# Routing logic between ingredient vs dish classifier
# ----------------------------------------------------------------------

def _route_label(
    detection: Detection,
    ingredient_top: list,
    dish_top: list,
) -> tuple:
    """
    Decide whether the label for this region should be an ingredient or a dish.

    Order of decisions:
      1. If both heads' top-1 prob is very low -> reject as 'unknown'
         (probably not food at all - hand, plate, utensil, etc.)
      2. If dish predicts a "complex dish" that has a plain-ingredient
         alternative AND the ingredient classifier sees the base ingredient
         with MODEST confidence (0.15-0.50) -> override to the simple
         ingredient (prevents 'plain rice -> fried_rice' overestimation).
      3. Big-region + confident dish -> dish.
      4. Confident-enough ingredient that beats dish -> ingredient.
      5. Confident dish (small region) -> dish.
      6. Fallback to whichever head has higher top-1.
    """
    ing_name, ing_prob = ingredient_top[0] if ingredient_top else (None, 0.0)
    dish_name, dish_prob = dish_top[0] if dish_top else (None, 0.0)

    # (1) Non-food reject
    if ing_prob < UNKNOWN_REJECT_FLOOR and dish_prob < UNKNOWN_REJECT_FLOOR:
        return "unknown", "unknown"

    # (2) Family guard: complex-dish -> simple-ingredient override
    if dish_name in DISH_TO_INGREDIENT_FALLBACK:
        expected_ingredient = DISH_TO_INGREDIENT_FALLBACK[dish_name]
        for ing_candidate, ing_candidate_prob in ingredient_top:
            if ing_candidate == expected_ingredient:
                if SIMPLE_INGREDIENT_MIN <= ing_candidate_prob < SIMPLE_INGREDIENT_MAX:
                    return (
                        ontology.ingredient_to_canonical(expected_ingredient),
                        "ingredient_override",
                    )
                break

    big_region = detection.mask_area_ratio >= config.DISH_MASK_AREA_RATIO

    if big_region and dish_prob >= config.DISH_CONF_FLOOR:
        return ontology.dish_to_canonical(dish_name), "dish"

    if ing_prob >= config.INGREDIENT_CONF_FLOOR and ing_prob >= dish_prob:
        return ontology.ingredient_to_canonical(ing_name), "ingredient"

    if dish_prob >= config.DISH_CONF_FLOOR:
        return ontology.dish_to_canonical(dish_name), "dish"

    if ing_prob >= dish_prob and ing_name is not None:
        return ontology.ingredient_to_canonical(ing_name), "ingredient"
    if dish_name is not None:
        return ontology.dish_to_canonical(dish_name), "dish"

    return "unknown", "unknown"


# ----------------------------------------------------------------------
# Detector helpers
# ----------------------------------------------------------------------

def _run_yolo_seg(detector_model, image_rgb: np.ndarray):
    """Run YOLOv8-seg and return a list of Detection objects (no labels yet)."""
    cv2 = _cv2()
    H, W = image_rgb.shape[:2]
    img_bgr = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR)

    pred = detector_model.predict(
        source=img_bgr,
        conf=config.PRODUCE_CONF_THRESHOLD,
        iou=config.PRODUCE_IOU_THRESHOLD,
        verbose=False,
    )[0]

    detections: List[Detection] = []
    if pred.masks is None or pred.boxes is None:
        return detections

    boxes_xyxy = pred.boxes.xyxy.cpu().numpy()
    scores = pred.boxes.conf.cpu().numpy()
    polys_xy = pred.masks.xy  # list of arrays (Nx2) in absolute pixel coords

    for box, score, poly_px in zip(boxes_xyxy, scores, polys_xy):
        if poly_px is None or len(poly_px) < 3:
            continue
        poly_norm = [[float(x) / W, float(y) / H] for x, y in poly_px]
        area_ratio = portion_mod.polygon_area_normalized(poly_norm)
        detections.append(Detection(
            bbox_xyxy=[float(v) for v in box],
            score=float(score),
            mask_area_ratio=float(area_ratio),
            polygon_xy_norm=poly_norm,
        ))

    return detections


def _polygon_to_binary_mask(poly_norm, H: int, W: int) -> np.ndarray:
    """Rasterize a normalized polygon to a HxW boolean mask."""
    cv2 = _cv2()
    mask = np.zeros((H, W), dtype=np.uint8)
    if len(poly_norm) >= 3:
        pts = np.array([[int(x * W), int(y * H)] for x, y in poly_norm], dtype=np.int32)
        cv2.fillPoly(mask, [pts], 1)
    return mask.astype(bool)


def _run_coco_detector(coco_model, image_rgb: np.ndarray) -> List[Detection]:
    """Run COCO-pretrained YOLO seg model. Return Detection objects with
    labels already filled in (label_source='coco'), keeping only food classes."""
    cv2 = _cv2()
    H, W = image_rgb.shape[:2]
    img_bgr = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR)

    pred = coco_model.predict(
        source=img_bgr,
        conf=COCO_CONF_THRESHOLD,
        iou=COCO_IOU_THRESHOLD,
        verbose=False,
    )[0]

    detections: List[Detection] = []
    if pred.boxes is None or len(pred.boxes) == 0:
        return detections

    boxes = pred.boxes.xyxy.cpu().numpy()
    cls_ids = pred.boxes.cls.cpu().numpy().astype(int)
    confs = pred.boxes.conf.cpu().numpy()
    masks_xy = list(pred.masks.xy) if pred.masks is not None else [None] * len(boxes)

    for box, cls_id, conf, mask_xy in zip(boxes, cls_ids, confs, masks_xy):
        if cls_id not in COCO_FOOD_CLASSES:
            continue
        coco_label = COCO_FOOD_CLASSES[cls_id]
        nutrition_key = COCO_TO_NUTRITION_KEY.get(coco_label, coco_label)

        if mask_xy is not None and len(mask_xy) >= 3:
            poly_norm = [[float(x) / W, float(y) / H] for x, y in mask_xy]
        else:
            # Fall back to bbox corners as polygon
            x1, y1, x2, y2 = box
            poly_norm = [
                [float(x1) / W, float(y1) / H],
                [float(x2) / W, float(y1) / H],
                [float(x2) / W, float(y2) / H],
                [float(x1) / W, float(y2) / H],
            ]
        area_ratio = portion_mod.polygon_area_normalized(poly_norm)

        det = Detection(
            bbox_xyxy=[float(v) for v in box],
            score=float(conf),
            mask_area_ratio=float(area_ratio),
            polygon_xy_norm=poly_norm,
        )
        det.label = nutrition_key
        det.label_source = "coco"
        det.ingredient_top = []
        det.dish_top = []
        detections.append(det)
    return detections


def _suppress_produce_overlapping_coco(
    coco_dets: List[Detection],
    produce_dets: List[Detection],
    image_shape,
) -> List[Detection]:
    """Drop produce detections that significantly overlap any COCO detection.
    COCO has higher label trust, so on overlap we let COCO win."""
    if not coco_dets or not produce_dets:
        return produce_dets

    H, W = image_shape[:2]
    coco_masks = [_polygon_to_binary_mask(d.polygon_xy_norm, H, W) for d in coco_dets]
    coco_areas = [int(m.sum()) for m in coco_masks]

    survivors: List[Detection] = []
    for p_det in produce_dets:
        p_mask = _polygon_to_binary_mask(p_det.polygon_xy_norm, H, W)
        p_area = int(p_mask.sum())
        if p_area == 0:
            continue

        suppressed = False
        for c_mask, c_area in zip(coco_masks, coco_areas):
            if c_area == 0:
                continue
            inter = int(np.logical_and(p_mask, c_mask).sum())
            if inter == 0:
                continue
            containment = inter / p_area
            iou = inter / max(1, p_area + c_area - inter)
            if (containment >= COCO_VS_PRODUCE_CONTAINMENT
                    or iou >= COCO_VS_PRODUCE_IOU):
                suppressed = True
                break

        if not suppressed:
            survivors.append(p_det)
    return survivors


def dedupe_overlapping_detections(
    detections: List[Detection],
    image_shape,
    containment_threshold: float = 0.70,
    iou_threshold: float = 0.60,
    same_class_only: bool = True,
    class_key=lambda d: getattr(d, "label", None),
) -> List[Detection]:
    """
    Suppress smaller detections that are mostly inside (or strongly overlap with)
    a larger detection.

    Catches the common YOLO failure mode:
      "whole pizza" detection AND "individual slice" detection are both reported,
      causing nutrition totals to double-count.

    Strategy
    --------
    1. Sort detections by mask area, descending (largest first).
    2. For each detection D (kept), suppress every smaller D' where either
         containment(D', D) = area(D ∩ D') / area(D')  >=  containment_threshold
         iou(D', D)                                    >=  iou_threshold
    3. Returns the surviving detections in their original order.

    Parameters
    ----------
    same_class_only : bool
        Only suppress within the same class_key. Use False to dedupe across
        all classes (useful for the binary "produce" detector where every
        detection has the same label).
    class_key : callable
        Function that returns a class identifier for each detection. Default
        uses the `label` attribute. For pre-classification dedup (no labels
        yet), pass `lambda d: 0` so everything is treated as one class.
    """
    n = len(detections)
    if n <= 1:
        return list(detections)

    H, W = image_shape[:2]
    masks = [_polygon_to_binary_mask(d.polygon_xy_norm, H, W) for d in detections]
    areas = np.array([int(m.sum()) for m in masks], dtype=np.int64)
    classes = [class_key(d) for d in detections]

    # Sort indices by area descending — keep the biggest, suppress nested smaller.
    order = sorted(range(n), key=lambda i: -int(areas[i]))

    suppressed = [False] * n
    for outer_pos, i in enumerate(order):
        if suppressed[i] or areas[i] == 0:
            continue
        mi = masks[i]
        ai = int(areas[i])
        for j in order[outer_pos + 1:]:
            if suppressed[j] or areas[j] == 0:
                continue
            if same_class_only and classes[i] != classes[j]:
                continue
            mj = masks[j]
            aj = int(areas[j])
            inter = int(np.logical_and(mi, mj).sum())
            if inter == 0:
                continue
            containment = inter / aj
            iou = inter / max(1, ai + aj - inter)
            if containment >= containment_threshold or iou >= iou_threshold:
                suppressed[j] = True

    return [detections[i] for i in range(n) if not suppressed[i]]


def _crop_with_mask(image_rgb: np.ndarray, det: Detection) -> np.ndarray:
    """
    Crop the bbox region and apply the polygon mask to suppress background.
    Returns an RGB image suitable for classification.
    """
    cv2 = _cv2()
    H, W = image_rgb.shape[:2]
    x1, y1, x2, y2 = [int(round(v)) for v in det.bbox_xyxy]
    x1, y1 = max(0, x1), max(0, y1)
    x2, y2 = min(W, x2), min(H, y2)
    if x2 <= x1 or y2 <= y1:
        return image_rgb

    full_mask = np.zeros((H, W), dtype=np.uint8)
    pts_px = np.array(
        [[int(x * W), int(y * H)] for x, y in det.polygon_xy_norm],
        dtype=np.int32,
    )
    cv2.fillPoly(full_mask, [pts_px], 255)

    masked = image_rgb.copy()
    masked[full_mask == 0] = 0
    crop = masked[y1:y2, x1:x2]
    return crop


# ----------------------------------------------------------------------
# Public API
# ----------------------------------------------------------------------

class NutriFilePipeline:
    """End-to-end inference object. Initialize once, reuse for many images."""

    def __init__(
        self,
        detector_weights: Path | str = config.PRODUCE_DETECTOR_WEIGHTS,
        ingredient_weights: Path | str = config.INGREDIENT_CLS_WEIGHTS,
        dish_weights: Path | str = config.DISH_CLS_WEIGHTS,
        coco_weights: Path | str | None = None,
        device: Optional[str] = None,
    ):
        YOLO = _yolo()
        self.detector = YOLO(str(detector_weights))

        # Optional: stock COCO-pretrained yolov8s-seg.pt for prepared dishes
        # (pizza, donut, cake, hot_dog, sandwich) that produce detector misses.
        self.coco_detector = None
        if coco_weights is not None and Path(coco_weights).exists():
            self.coco_detector = YOLO(str(coco_weights))

        self.ingredient_clf = None
        self.dish_clf = None

        if Path(ingredient_weights).exists():
            self.ingredient_clf = cls_mod.load_classifier(
                ingredient_weights, device=device
            )
        if Path(dish_weights).exists():
            self.dish_clf = cls_mod.load_classifier(
                dish_weights, device=device
            )

    # ------------------------------------------------------------------
    def run(
        self,
        image_rgb: np.ndarray,
        user_goal: str = "maintenance",
        target_kcal: float = 2000.0,
    ) -> PipelineResult:
        H, W = image_rgb.shape[:2]

        # Produce detector (binary "is this food?", trained on PackEat)
        produce_dets = _run_yolo_seg(self.detector, image_rgb)

        # COCO ensemble (optional): stock yolov8s-seg knows pizza/donut/cake/etc.
        coco_dets: List[Detection] = []
        if self.coco_detector is not None:
            coco_dets = _run_coco_detector(self.coco_detector, image_rgb)

        # ----------------------------------------------------------
        # Pre-classification dedup of produce detections among themselves.
        # The trained produce detector emits only one class ("produce"),
        # so they're all interchangeable -- same_class_only=False treats
        # them as one bucket.
        # ----------------------------------------------------------
        if config.DEDUPE_ENABLED and len(produce_dets) > 1:
            produce_dets = dedupe_overlapping_detections(
                produce_dets,
                image_shape=image_rgb.shape,
                containment_threshold=config.DEDUPE_CONTAINMENT_THRESHOLD,
                iou_threshold=config.DEDUPE_IOU_THRESHOLD,
                same_class_only=False,
                class_key=lambda d: 0,
            )

        # When COCO detected pizza/cake/etc., drop produce detections that
        # overlap with it (COCO has higher label trust).
        produce_dets = _suppress_produce_overlapping_coco(
            coco_dets, produce_dets, image_rgb.shape
        )

        detections = list(coco_dets) + list(produce_dets)

        # ----------------------------------------------------------
        # Per-detection: classify (skip for COCO) + portion + nutrition
        # ----------------------------------------------------------
        for det in detections:
            if det.label_source == "coco":
                # COCO already gave us a confident label; skip the classifier.
                pass
            else:
                crop = _crop_with_mask(image_rgb, det)

                if self.ingredient_clf is not None:
                    det.ingredient_top = cls_mod.predict_topk(self.ingredient_clf, crop, topk=3)
                if self.dish_clf is not None:
                    det.dish_top = cls_mod.predict_topk(self.dish_clf, crop, topk=3)

                det.label, det.label_source = _route_label(det, det.ingredient_top, det.dish_top)

            entry = nutrition.lookup(det.label)
            est = portion_mod.estimate_grams(
                mask_area_ratio=det.mask_area_ratio,
                density_g_per_cm2=float(entry["density_g_per_cm2"]),
            )
            det.portion = est.to_dict()

            grams = est.grams
            det.nutrition = {
                "kcal":    round(entry["kcal"]    * grams / 100, 1),
                "carbs":   round(entry["carbs"]   * grams / 100, 1),
                "protein": round(entry["protein"] * grams / 100, 1),
                "fat":     round(entry["fat"]     * grams / 100, 1),
                "sugar":   round(entry["sugar"]   * grams / 100, 1),
                "sodium":  round(entry["sodium"]  * grams / 100, 1),
                "fiber":   round(entry["fiber"]   * grams / 100, 1),
                "confidence": entry.get("confidence", "low"),
                "source_per_100g": {
                    k: entry[k]
                    for k in ("kcal", "carbs", "protein", "fat",
                              "sugar", "sodium", "fiber")
                },
            }

        # ----------------------------------------------------------
        # Aggregate
        # ----------------------------------------------------------
        agg = {"kcal": 0.0, "carbs": 0.0, "protein": 0.0, "fat": 0.0,
               "sugar": 0.0, "sodium": 0.0, "fiber": 0.0, "total_grams": 0.0}
        for det in detections:
            if det.nutrition is None:
                continue
            agg["kcal"]    += det.nutrition["kcal"]
            agg["carbs"]   += det.nutrition["carbs"]
            agg["protein"] += det.nutrition["protein"]
            agg["fat"]     += det.nutrition["fat"]
            agg["sugar"]   += det.nutrition["sugar"]
            agg["sodium"]  += det.nutrition["sodium"]
            agg["fiber"]   += det.nutrition["fiber"]
            agg["total_grams"] += det.portion["grams"]
        agg = {k: round(v, 1) for k, v in agg.items()}

        # ----------------------------------------------------------
        # Recommendation + explanation
        # ----------------------------------------------------------
        recs = rec_mod.recommendations_for(agg, goal=user_goal, target_kcal=target_kcal)
        text = exp_mod.summarize(detections, agg, recs, goal=user_goal,
                                 target_kcal=target_kcal)

        return PipelineResult(
            image_shape=(H, W, image_rgb.shape[2] if image_rgb.ndim == 3 else 1),
            detections=detections,
            aggregated_nutrition=agg,
            recommendations=recs,
            explanation=text,
        )
