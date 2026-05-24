from __future__ import annotations

import os
from pathlib import Path


# deteksi platform (kaggle, colab, atau lokal)

def detect_platform() -> str:
    """Return 'kaggle', 'colab', atau 'local'."""
    if "KAGGLE_KERNEL_RUN_TYPE" in os.environ or Path("/kaggle/working").exists():
        return "kaggle"
    if "COLAB_GPU" in os.environ or Path("/content").exists():
        return "colab"
    return "local"


PLATFORM = detect_platform()


# folder root

if PLATFORM == "kaggle":
    DATA_ROOT = Path("/kaggle/working")
    WORK_ROOT = Path("/kaggle/working")
elif PLATFORM == "colab":
    DATA_ROOT = Path("/content")
    WORK_ROOT = Path("/content")
else:
    # local fallback (e.g. running tests on a dev box)
    DATA_ROOT = Path.home() / "nutrifile_data"
    WORK_ROOT = Path.home() / "nutrifile_work"

DATA_ROOT.mkdir(parents=True, exist_ok=True)
WORK_ROOT.mkdir(parents=True, exist_ok=True)


# lokasi dataset mentah
#
# di Kaggle, dataset yang di-attach lewat "+ Add Data" ada di /kaggle/input/<slug>/
# (read-only). Kalau tidak ada, fallback ke DATA_ROOT.

_KAGGLE_INPUT = Path("/kaggle/input")


def _resolve_dataset(*candidates: Path) -> Path:
    """Return candidate path pertama yang ada; kalau tidak ada, pakai yang terakhir."""
    for c in candidates:
        if c.exists():
            return c
    return candidates[-1]


RAW_FOOD101 = _resolve_dataset(
    _KAGGLE_INPUT / "food41",
    DATA_ROOT / "food101",
)
RAW_PACKEAT = _resolve_dataset(
    _KAGGLE_INPUT / "packed-fruits-and-vegetables-recognition-benchmark",
    DATA_ROOT / "packed-fruits-and-vegetable",
)
RAW_SINGULAR = _resolve_dataset(
    _KAGGLE_INPUT / "singular-food-items",
    DATA_ROOT / "singular-food-items",
)


# dataset yang sudah di-preprocess (siap training)

PRODUCE_SEG_DIR = WORK_ROOT / "produce_dataset"          # YOLOv8-seg, 1 class
INGREDIENT_CLS_DIR = WORK_ROOT / "ingredient_cls_dataset"  # ImageFolder, 51 classes
DISH_CLS_DIR = WORK_ROOT / "dish_cls_dataset"              # ImageFolder, 101 classes


# output dan artefak training

RUNS_DIR = WORK_ROOT / "runs"
WEIGHTS_DIR = WORK_ROOT / "weights"
NUTRITION_DB_PATH = WORK_ROOT / "nutrition_db.json"

RUNS_DIR.mkdir(parents=True, exist_ok=True)
WEIGHTS_DIR.mkdir(parents=True, exist_ok=True)


# nama file bobot model (dipakai di seluruh codebase)

PRODUCE_DETECTOR_WEIGHTS = WEIGHTS_DIR / "produce_yolov8s_seg.pt"
INGREDIENT_CLS_WEIGHTS = WEIGHTS_DIR / "ingredient_effnetb0.pt"
DISH_CLS_WEIGHTS = WEIGHTS_DIR / "dish_effnetb0.pt"


# hyperparameter training (satu sumber kebenaran)

SEED = 42

PRODUCE_TRAIN = dict(
    model_variant="yolov8s-seg.pt",
    epochs=40,
    imgsz=640,
    batch=16,
    patience=8,
    optimizer="auto",
    mosaic=1.0,
    close_mosaic=10,
    hsv_h=0.015,
    hsv_s=0.7,
    hsv_v=0.4,
    flipud=0.0,
    fliplr=0.5,
    degrees=10.0,
    translate=0.1,
    scale=0.5,
)

CLS_TRAIN = dict(
    backbone="efficientnet_b0",
    image_size=224,
    batch_size=64,
    epochs=15,
    lr=3e-4,
    weight_decay=1e-4,
    label_smoothing=0.05,
    mixup=0.1,
    num_workers=4,
)


# threshold inferensi

PRODUCE_CONF_THRESHOLD = 0.15    # was 0.30 -- detector was suppressing real food
PRODUCE_IOU_THRESHOLD = 0.55
INGREDIENT_CONF_FLOOR = 0.55     # was 0.40 -- ingredient head was winning the router too easily
DISH_CONF_FLOOR = 0.45

# When mask covers >= DISH_MASK_AREA_RATIO of the image, prefer dish classifier
# (a single large region is usually a prepared meal, not a single ingredient).
DISH_MASK_AREA_RATIO = 0.10      # was 0.30 -- plated food regions are usually smaller

# deduplikasi deteksi bersarang
#
# NMS standar menekan box yang overlap berdasarkan IoU, tapi tidak
# menangkap kasus di mana satu deteksi SEPENUHNYA MEMUAT deteksi lain
# (misal: pizza utuh DAN sepotong kecil di dalamnya). Tanpa ini,
# total nutrisi terhitung dua kali.
#
# Deteksi kecil D' dibuang kalau salah satu terpenuhi:
#   - containment(D', D) = area(D n D') / area(D')  >=  CONTAINMENT_THRESHOLD
#   - iou(D', D)                                    >=  IOU_THRESHOLD
# D = deteksi besar yang sudah di-keep (opsional same-class only).

DEDUPE_ENABLED = True
DEDUPE_CONTAINMENT_THRESHOLD = 0.70
DEDUPE_IOU_THRESHOLD = 0.60
DEDUPE_SAME_CLASS_ONLY = True


def summary() -> str:
    """Ringkasan konfigurasi yang sedang aktif, buat logging."""
    return (
        f"NutriFile config\n"
        f"  platform           : {PLATFORM}\n"
        f"  DATA_ROOT          : {DATA_ROOT}\n"
        f"  WORK_ROOT          : {WORK_ROOT}\n"
        f"  RAW_FOOD101        : {RAW_FOOD101}\n"
        f"  RAW_PACKEAT        : {RAW_PACKEAT}\n"
        f"  RAW_SINGULAR       : {RAW_SINGULAR}\n"
        f"  PRODUCE_SEG_DIR    : {PRODUCE_SEG_DIR}\n"
        f"  INGREDIENT_CLS_DIR : {INGREDIENT_CLS_DIR}\n"
        f"  DISH_CLS_DIR       : {DISH_CLS_DIR}\n"
        f"  WEIGHTS_DIR        : {WEIGHTS_DIR}\n"
        f"  NUTRITION_DB_PATH  : {NUTRITION_DB_PATH}\n"
    )
