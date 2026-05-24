"""
Meal analysis service — the brain of /analyze_meal.

Orchestrates:
  1. Image saving
  2. Pipeline execution (NutriFilePipeline)
  3. Annotated image generation
  4. Structured JSON assembly
  5. Knowledge inference (hidden ingredients)
  6. Goal-aware reasoning
  7. TDEE calculation from biometrics
"""

from __future__ import annotations

import sys
from pathlib import Path
from typing import Optional
from uuid import uuid4

import cv2
import numpy as np

# ── Make the nutrifile package importable ─────────────────────────────
# app/services/meal_service.py → parents[2] = Nutrify-Food-Recognition-And-Daily-Food-Scheduler/
_NUTRIFILE_PKG = Path(__file__).resolve().parents[2] / "Machine Learning" / "food_detection"
if str(_NUTRIFILE_PKG) not in sys.path:
    sys.path.insert(0, str(_NUTRIFILE_PKG))

from nutrifile.pipeline import NutriFilePipeline, PipelineResult, Detection
from nutrifile import recommend as rec_mod

from app.core.settings import get_settings
from app.core.knowledge import get_hidden_ingredients
from app.models.schemas import (
    MealAnalysisResponse,
    MealData,
    DishPrediction,
    IngredientDetail,
    NutritionInfo,
    PortionEstimate,
    GoalAnalysis,
)


# ══════════════════════════════════════════════════════════════════════
# TDEE (Total Daily Energy Expenditure) calculator
# ══════════════════════════════════════════════════════════════════════

ACTIVITY_MULTIPLIERS = {
    "sedentary":   1.2,
    "light":       1.375,
    "moderate":    1.55,
    "active":      1.725,
    "very_active": 1.9,
}


def calculate_tdee(
    weight: float,
    height: float,
    age: int,
    gender: str,
    activity_level: str,
    goal: str,
) -> float:
    """
    Mifflin-St Jeor equation → TDEE → goal-adjusted daily target.

    Returns daily kcal target.
    """
    if gender == "male":
        bmr = 10 * weight + 6.25 * height - 5 * age + 5
    else:
        bmr = 10 * weight + 6.25 * height - 5 * age - 161

    multiplier = ACTIVITY_MULTIPLIERS.get(activity_level, 1.55)
    tdee = bmr * multiplier

    if goal == "weight_loss":
        return tdee - 500  # ~0.5 kg/week deficit
    elif goal == "muscle_gain":
        return tdee + 300  # slight surplus
    return tdee  # maintenance


# ══════════════════════════════════════════════════════════════════════
# Singleton pipeline loader
# ══════════════════════════════════════════════════════════════════════

_pipeline: Optional[NutriFilePipeline] = None


def _get_pipeline() -> NutriFilePipeline:
    global _pipeline
    if _pipeline is None:
        settings = get_settings()
        _pipeline = NutriFilePipeline(
            detector_weights=settings.weight_path("produce_yolov8s_seg.pt"),
            ingredient_weights=settings.weight_path("ingredient_effnetb0.pt"),
            dish_weights=settings.weight_path("dish_effnetb0.pt"),
            coco_weights=settings.coco_weights if settings.coco_weights.exists() else None,
            device=None,
        )
    return _pipeline


# ══════════════════════════════════════════════════════════════════════
# Image I/O
# ══════════════════════════════════════════════════════════════════════

def save_upload(image_bytes: bytes, ext: str = ".jpg") -> tuple[Path, str]:
    """Save uploaded bytes; return (full_path, relative_url)."""
    settings = get_settings()
    settings.upload_dir.mkdir(parents=True, exist_ok=True)
    filename = f"{uuid4().hex}{ext}"
    full_path = settings.upload_dir / filename
    full_path.write_bytes(image_bytes)
    return full_path, f"/uploads/{filename}"


def render_annotated(image_rgb: np.ndarray, result: PipelineResult) -> tuple[Path, str]:
    """Draw bounding boxes + labels on image; save and return path."""
    settings = get_settings()
    settings.upload_dir.mkdir(parents=True, exist_ok=True)

    img_bgr = cv2.cvtColor(image_rgb, cv2.COLOR_RGB2BGR)
    overlay = img_bgr.copy()
    H, W = img_bgr.shape[:2]

    palette = [
        (0, 200, 0), (255, 100, 0), (0, 165, 255),
        (255, 0, 255), (0, 255, 255), (128, 0, 255),
        (0, 0, 220), (0, 80, 255), (60, 80, 255),
    ]

    for i, det in enumerate(result.detections):
        color = palette[i % len(palette)]

        # Draw polygon mask overlay
        if det.polygon_xy_norm and len(det.polygon_xy_norm) >= 3:
            pts = np.array(
                [[int(x * W), int(y * H)] for x, y in det.polygon_xy_norm],
                dtype=np.int32,
            )
            cv2.fillPoly(overlay, [pts], color)

        # Draw bounding box
        x1, y1, x2, y2 = [int(v) for v in det.bbox_xyxy]
        cv2.rectangle(img_bgr, (x1, y1), (x2, y2), color, 2)

        # Label with nutrition
        grams = det.portion["grams"] if det.portion else 0
        kcal = det.nutrition["kcal"] if det.nutrition else 0
        label_text = f"{det.label} {grams:.0f}g {kcal:.0f}kcal"

        font = cv2.FONT_HERSHEY_SIMPLEX
        font_scale = 0.55
        thickness = 2
        (tw, th), _ = cv2.getTextSize(label_text, font, font_scale, thickness)
        ytxt = max(0, y1 - 8)
        cv2.rectangle(img_bgr, (x1, ytxt - th - 4), (x1 + tw + 6, ytxt + 2), color, -1)
        cv2.putText(img_bgr, label_text, (x1 + 3, ytxt - 2), font, font_scale, (255, 255, 255), thickness)

    blended = cv2.addWeighted(img_bgr, 0.65, overlay, 0.35, 0)

    filename = f"annotated_{uuid4().hex[:12]}.jpg"
    full_path = settings.upload_dir / filename
    cv2.imwrite(str(full_path), blended, [cv2.IMWRITE_JPEG_QUALITY, 90])
    return full_path, f"/uploads/{filename}"


# ══════════════════════════════════════════════════════════════════════
# Helpers
# ══════════════════════════════════════════════════════════════════════

def _classify_portion_size(grams: float) -> str:
    if grams < 100:
        return "small"
    elif grams < 250:
        return "medium"
    return "large"


def _find_dish_detection(detections: list[Detection]) -> Optional[Detection]:
    """
    Find the primary dish detection.

    Priority order:
      1. "dish" source detections (actual dish classifier: fried_rice, pizza, etc.)
         — sorted by mask_area_ratio * score to prefer large, confident dish regions
      2. "coco" detections that are composite dishes (pizza, sandwich, hot_dog, cake, donut)
      3. Largest detection by mask area as fallback
    """
    # Composite COCO labels that represent full dishes (not single ingredients)
    COCO_DISH_LABELS = {"pizza", "club_sandwich", "hot_dog", "donuts", "chocolate_cake"}

    # Priority 1: actual dish classifier hits
    dish_source_dets = [d for d in detections if d.label_source == "dish"]
    if dish_source_dets:
        return max(dish_source_dets, key=lambda d: d.mask_area_ratio * d.score)

    # Priority 2: COCO detections that are composite dishes
    coco_dish_dets = [d for d in detections if d.label_source == "coco" and d.label in COCO_DISH_LABELS]
    if coco_dish_dets:
        return max(coco_dish_dets, key=lambda d: d.score)

    # Priority 3: largest detection by mask area
    if detections:
        return max(detections, key=lambda d: d.mask_area_ratio)
    return None


def _collect_hidden_ingredients(detections: list[Detection]) -> list[str]:
    """
    Collect hidden ingredients from ALL dish-type detections.
    De-duplicated and sorted for consistent output.
    """
    hidden = set()
    for det in detections:
        if det.label_source in ("dish",) and det.label:
            hidden.update(get_hidden_ingredients(det.label))
    return sorted(hidden)


# ══════════════════════════════════════════════════════════════════════
# Main analysis entry point
# ══════════════════════════════════════════════════════════════════════

def analyze_meal(
    image_bytes: bytes,
    goal: str,
    weight: float,
    height: float,
    age: int,
    gender: str,
    activity_level: str,
    daily_target: Optional[float] = None,
    ext: str = ".jpg",
) -> MealAnalysisResponse:
    """
    Full meal analysis pipeline.

    Returns a structured MealAnalysisResponse ready for JSON serialization.
    """
    settings = get_settings()

    # ── 1. Save original image ────────────────────────────────────────
    original_path, original_url = save_upload(image_bytes, ext)

    # ── 2. Calculate TDEE if no explicit target ───────────────────────
    if daily_target is None or daily_target <= 0:
        daily_target = calculate_tdee(weight, height, age, gender, activity_level, goal)

    meal_target_kcal = daily_target / settings.default_meals_per_day

    # ── 3. Load image into numpy array ────────────────────────────────
    nparr = np.frombuffer(image_bytes, np.uint8)
    img_bgr = cv2.imdecode(nparr, cv2.IMREAD_COLOR)
    if img_bgr is None:
        raise ValueError("Could not decode image. Ensure the file is a valid image.")
    img_rgb = cv2.cvtColor(img_bgr, cv2.COLOR_BGR2RGB)

    # ── 4. Run ML pipeline ────────────────────────────────────────────
    pipe = _get_pipeline()
    result: PipelineResult = pipe.run(
        img_rgb,
        user_goal=goal,
        target_kcal=daily_target,
    )

    # ── 5. Render annotated image ─────────────────────────────────────
    _, annotated_url = render_annotated(img_rgb, result)

    # ── 6. Build structured response ──────────────────────────────────

    # Identify the primary dish
    primary_det = _find_dish_detection(result.detections)
    dish_prediction = None
    hidden_ingredients = _collect_hidden_ingredients(result.detections)

    if primary_det and primary_det.label_source in ("dish", "coco"):
        dish_prediction = DishPrediction(
            label=primary_det.label,
            confidence=round(primary_det.score, 2),
            top_candidates=[
                {"label": name, "probability": round(prob, 4)}
                for name, prob in primary_det.dish_top
            ] if primary_det.dish_top else [],
        )
        # If hidden ingredients weren't found from dish detections,
        # try from the primary dish label
        if not hidden_ingredients:
            hidden_ingredients = get_hidden_ingredients(primary_det.label)

    # Build ingredient list
    ingredients = []
    total_grams = 0.0
    for det in result.detections:
        grams = det.portion["grams"] if det.portion else 0.0
        total_grams += grams
        nut = det.nutrition or {}
        ingredients.append(IngredientDetail(
            label=det.label or "unknown",
            confidence=round(det.score, 2),
            grams=round(grams, 1),
            source=det.label_source or "unknown",
            nutrition=NutritionInfo(
                calories=nut.get("kcal", 0),
                protein=nut.get("protein", 0),
                carbs=nut.get("carbs", 0),
                fat=nut.get("fat", 0),
                sugar=nut.get("sugar", 0),
                sodium=nut.get("sodium", 0),
                fiber=nut.get("fiber", 0),
            ),
        ))

    # Portion estimate for the whole meal
    portion_estimate = PortionEstimate(
        size=_classify_portion_size(total_grams),
        grams=round(total_grams, 1),
        area_cm2=round(sum(
            (d.portion or {}).get("area_cm2", 0)
            for d in result.detections
        ), 1),
        method="mask_area_ratio",
    )

    # Nutrition totals
    agg = result.aggregated_nutrition
    nutrition_total = NutritionInfo(
        calories=agg.get("kcal", 0),
        protein=agg.get("protein", 0),
        carbs=agg.get("carbs", 0),
        fat=agg.get("fat", 0),
        sugar=agg.get("sugar", 0),
        sodium=agg.get("sodium", 0),
        fiber=agg.get("fiber", 0),
    )

    # Goal analysis & warnings
    targets = rec_mod.per_meal_targets(daily_target, meals_per_day=settings.default_meals_per_day)
    warnings = []
    for rec in result.recommendations:
        if rec.get("severity") in ("alert", "warning"):
            warnings.append(rec["message"])

    goal_analysis = GoalAnalysis(
        goal=goal,
        daily_target_calories=round(daily_target, 0),
        meal_target_calories=round(meal_target_kcal, 0),
        protein_target=round(targets["protein"], 1),
        warnings=warnings,
    )

    # Friendly recommendation strings
    recommendation_messages = [rec["message"] for rec in result.recommendations]

    return MealAnalysisResponse(
        status="success",
        meal=MealData(
            dish_prediction=dish_prediction,
            ingredients=ingredients,
            estimated_hidden_ingredients=hidden_ingredients,
            portion_estimate=portion_estimate,
        ),
        nutrition_total=nutrition_total,
        goal_analysis=goal_analysis,
        recommendations=recommendation_messages,
        detailed_suggestions=result.recommendations,
        explanation=result.explanation,
        images={
            "original": original_url,
            "annotated": annotated_url,
        },
    )
