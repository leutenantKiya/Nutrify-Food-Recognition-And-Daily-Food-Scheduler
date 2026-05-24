# NutriFile ML

End-to-end food computer vision system. From a single image we produce:

```
image
 -> Stage 1: produce segmentation (YOLOv8-seg, binary)
 -> Stage 2: per-region classification
              - ingredient head (50 raw ingredient classes)
              - dish head       (101 cooked-dish classes from Food101)
              - router picks ingredient vs dish per region
 -> Stage 3: portion estimation (mask area * density)
 -> Stage 4: nutrition aggregation (per-class per-100g lookup)
 -> Stage 5: rule-based recommendation
 -> Stage 6: human-readable explanation
```

## Why this architecture

The three available datasets are nutritionally orthogonal:

| Dataset | Used for | Why |
|---|---|---|
| **PackEat** (5852 segmentation labels) | Stage 1 detector | The 71 YOLO class IDs do NOT map to the 65 taxonomy variety classes (verified by single-class voting: every class id sees <26% confidence to any taxonomy label). Polygons themselves are accurate, so we collapse all 71 IDs into a single binary `produce` class. |
| **Singular Food Items** (98k images, 51 folders) | Stage 2 ingredient head | 50 clean raw-ingredient classes after dropping the `noise` folder. |
| **Food101** (101k images, 101 classes) | Stage 2 dish head | 101 cooked-dish classes. Crucial because end users photograph plated meals, not raw ingredients. |

No attempt is made to merge raw ingredients with cooked dishes - they have different macros and a "rice" raw vs "fried_rice" dish are kept as separate nutrition entries.

## Layout

```
food_detection/
├── README.md                                this file
├── _build_notebooks.py                      regenerates the .ipynb files
├── 00_setup.ipynb                           writes the package + runs sanity checks
├── 01_data_prep.ipynb                       downloads + cleans + splits all 3 datasets
├── 02_train_produce_detector.ipynb          trains YOLOv8s-seg, 1 class
├── 03_train_ingredient_classifier.ipynb     EfficientNet-B0, 50 ingredient classes
├── 04_train_dish_classifier.ipynb           EfficientNet-B0, 101 Food101 classes
├── 05_inference_demo.ipynb                  full pipeline demo + viz
├── kaggle_connect.ipynb                     original exploration notebook (kept for reference)
└── nutrifile/                               importable Python package
    ├── __init__.py
    ├── config.py          platform-aware paths (Kaggle / Colab / local)
    ├── ontology.py        canonical class names + folder normalization
    ├── nutrition.py       per-100g macros for all 151 canonical keys
    ├── portion.py         polygon area -> grams via density
    ├── classifier.py      EfficientNet-B0 wrapper (train + load + predict)
    ├── pipeline.py        NutriFilePipeline: orchestrates the full flow
    ├── recommend.py       rule-based suggestion engine (7 rules)
    └── explain.py         human-readable meal summary
```

## How do I test that the model works?

Test in **three layers** of increasing cost:

### Layer 1 — Unit tests (no ML, runs locally in <1 s)

Tests the deterministic parts: nutrition DB coverage, portion math, polygon area, recommendation rules, explanation formatter.

```bash
cd food_detection
pip install pytest
python -m pytest          # 26 tests, ~0.6 s
```

A passing run looks like:

```
tests/test_nutrition.py::test_db_has_at_least_one_entry_per_class PASSED
tests/test_portion.py::test_default_estimate_uses_default_frame_area PASSED
tests/test_recommend.py::test_junk_meal_weight_loss_triggers_alerts PASSED
...
============================= 26 passed in 0.60s ==============================
```

If any of these fail, the bug is in your DB / config / rule logic, not the ML.

### Layer 2 — Smoke-test notebook (no training, ~2 min on Kaggle)

`99_smoke_test.ipynb` runs the **entire pipeline** end-to-end using `yolov8s-seg.pt` pretrained on COCO as a stand-in for the produce detector. COCO contains banana, apple, sandwich, orange, broccoli, carrot, hot_dog, pizza, donut, cake, so it's enough to verify:

* the bootstrap cell writes the `nutrifile/` package correctly
* `ultralytics` is installed and GPU is reachable
* detection -> polygon -> mask area -> portion grams works
* nutrition lookup returns sane numbers
* recommendation rules fire on real model output
* the explanation text gets generated

Upload `99_smoke_test.ipynb` to Kaggle, run all cells. The last cell prints either `SMOKE TEST PASSED.` with detection counts and totals, or `SMOKE TEST FAILED:` with the exact failed check.

You can also point it at your own image by setting `TEST_IMAGE_PATH = "/kaggle/input/.../my_plate.jpg"` in step 2.

### Layer 3 — Full evaluation (after you train)

Each training notebook (02-04) runs validation at the end of training and prints metrics. Specifically:

* **02_train_produce_detector.ipynb** prints `Box mAP50`, `Box mAP50-95`, `Mask mAP50`, `Mask mAP50-95` on the held-out PackEat test split, and saves `viz_test_samples.png` (6 random predictions overlaid on the input).
* **03/04 classifier notebooks** print overall test accuracy and the worst/best 10 classes per-class, so you can see which classes are weak.
* **05_inference_demo.ipynb** runs the full chained pipeline with the trained models on random PackEat test images, prints structured output, and renders `inference_demo.png` showing labels + portion + kcal on each region.

Suggested success thresholds:

| Stage | Metric | Good | Needs work |
|---|---|---|---|
| Produce detector | Mask mAP50 | > 0.80 | < 0.70 |
| Produce detector | Mask mAP50-95 | > 0.55 | < 0.40 |
| Ingredient classifier | Top-1 test acc | > 0.75 | < 0.60 |
| Dish classifier | Top-1 test acc | > 0.70 | < 0.55 |

If the trained metrics are below the "Needs work" line, the most likely fixes (in order):

1. Verify `01_data_prep.ipynb` actually copied images for every class (the inventory cell prints counts).
2. Train longer (increase `epochs` in `nutrifile/config.py`).
3. Switch to a bigger backbone (`yolov8m-seg.pt`, `efficientnet_b3`).
4. Add stronger augmentation (`mosaic`, `mixup` are already on; try `degrees=15`, `translate=0.2`).

### Quick troubleshooting checklist

| Symptom | Likely cause | Fix |
|---|---|---|
| `kaggle: command not found` | Notebook 01 step 1 | `%pip install kaggle` then re-run download cell |
| `CUDA not available` | GPU not attached | Kaggle: Settings -> Accelerator -> GPU T4 |
| `RuntimeError: dataset path does not exist` | Skipped notebook 01 | Run 01 before 02-05 |
| `Missing nutrition entries: [...]` | Added a new class but no DB entry | Add entry in `nutrifile/nutrition.py` |
| Smoke test detects 0 food | Image had no COCO food classes | Set `TEST_IMAGE_PATH` to a plate image or lower `conf` to 0.15 |
| `KeyError: 'noise'` after training | Singular folder named `noise` leaked into class list | Re-run `01_data_prep.ipynb` (it filters this) |

## How to run on Kaggle

**Recommended — one combined master notebook (~5-6 h, single session)**

1. Create a new Kaggle Notebook.
2. **Settings -> Accelerator -> GPU T4 x2** (or P100).
3. **+ Add Data** -> attach all three datasets:
   * `kmader/food41`
   * `sergeynesteruk/packed-fruits-and-vegetables-recognition-benchmark`
   * `liamboyd1/singular-food-items`
4. **Settings -> Internet -> ON** (so it can download pretrained weights).
5. **File -> Import Notebook** -> upload `nutrifile_master.ipynb`.
6. **Run All**. The notebook does data prep -> 3 trainings -> end-to-end inference in one session.
7. Click **Save Version** when done. The trained weights (`/kaggle/working/weights/*`) become a downloadable Notebook Output dataset.

The master notebook is **idempotent**: re-running it skips stages whose outputs already exist, so if the session times out at, say, Stage 3, you can just hit Run All again and it resumes from where it stopped. Each stage also has a `STAGE_*` boolean at the top you can flip to False to selectively skip.

**Alternative — run notebooks individually**

If you prefer the modular path (one Kaggle notebook per stage, sharing outputs via "Notebook Output" datasets), upload the numbered notebooks in order:

* `00_setup.ipynb` (5 s, sanity checks)
* `01_data_prep.ipynb` (~10 min, symlinks - no big copies)
* `02_train_produce_detector.ipynb` (~1 h on T4)
* `03_train_ingredient_classifier.ipynb` (~1.5 h on T4)
* `04_train_dish_classifier.ipynb` (~2.5 h on T4)
* `05_inference_demo.ipynb` (a few seconds per image)

Each one re-runs the bootstrap cell, so they're independent. After running each, click Save Version, then in the next notebook attach the previous one's output via **+ Add Data -> Notebook Output**.

## How to run locally / on Colab

The package auto-detects platform via `nutrifile.config.detect_platform()`:

* Kaggle: `KAGGLE_KERNEL_RUN_TYPE` env var, paths under `/kaggle/working`.
* Colab: `/content` exists, paths under `/content`.
* Local: paths under `~/nutrifile_data` and `~/nutrifile_work`.

No code change required to move between them.

## Regenerating the notebooks

The notebooks are generated from `_build_notebooks.py`. Edit the Python file and rerun:

```bash
python _build_notebooks.py
```

This is the single source of truth - do not hand-edit the `.ipynb` files unless you are happy with the change being overwritten.

## Module-level API

```python
import cv2
from nutrifile.pipeline import NutriFilePipeline

pipe = NutriFilePipeline()              # loads detector + both classifiers
img  = cv2.cvtColor(cv2.imread("plate.jpg"), cv2.COLOR_BGR2RGB)
res  = pipe.run(img, user_goal="weight_loss", target_kcal=2000)

print(res.explanation)                  # human-readable summary
print(res.aggregated_nutrition)         # {'kcal': ..., 'protein': ..., ...}
for det in res.detections:
    print(det.label, det.portion["grams"], det.nutrition["kcal"])
```

## Configuration knobs (in `nutrifile/config.py`)

| Symbol | Meaning | Default |
|---|---|---|
| `PRODUCE_TRAIN` | YOLOv8-seg hyperparameters | 40 epochs, imgsz 640, batch 16 |
| `CLS_TRAIN` | EfficientNet-B0 hyperparameters | 15 epochs, lr 3e-4, batch 64 |
| `PRODUCE_CONF_THRESHOLD` | Min detector confidence | 0.30 |
| `INGREDIENT_CONF_FLOOR` | Min top-1 ingredient prob before we trust it | 0.40 |
| `DISH_CONF_FLOOR` | Min top-1 dish prob before we trust it | 0.45 |
| `DISH_MASK_AREA_RATIO` | Mask fraction above which router prefers dish over ingredient | 0.30 |

## Rule-based recommendation engine

See `nutrifile/recommend.py`. Seven rules cover:

* `CAL_OVER_WEIGHT_LOSS` / `CAL_UNDER_MUSCLE` / `CAL_OFF_MAINTENANCE`
* `LOW_PROTEIN`
* `HIGH_SUGAR`
* `HIGH_SODIUM`
* `HIGH_FAT`
* `LOW_FIBER`
* `CARB_DOMINANT` / `FAT_DOMINANT` / `LOW_PROTEIN_PCT`

Each rule emits a structured `{code, severity, message, evidence}` suggestion, so the frontend can show them in any order and styling.

## Open improvements

* **Better depth cue for portion**: monocular depth (MiDaS) would replace the flat-plate assumption.
* **Multi-label dish detection**: some plates contain >1 dish (e.g. steak + fries). The current router picks one per region; a joint classifier could be added.
* **Calibration**: classifier confidences are slightly overconfident; temperature scaling would tighten the routing thresholds.
* **Ontology merge for fruits**: the Singular `apple` and Food101 `apple_pie` are separate, but a region containing both could be modeled hierarchically.
