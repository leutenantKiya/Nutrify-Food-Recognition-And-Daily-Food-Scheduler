"""
Konfigurasi utama, dimuat sekali saat startup.

Environment variable bisa override default:
    NUTRIFILE_WEIGHTS_DIR, NUTRIFILE_UPLOAD_DIR, dll.
"""

from __future__ import annotations

import os
from pathlib import Path
from functools import lru_cache

from pydantic_settings import BaseSettings


# ── Resolve project paths ────────────────────────────────────────────
# app/core/settings.py → parents[2] = Nutrify-Food-Recognition-And-Daily-Food-Scheduler/
_PROJECT_ROOT = Path(__file__).resolve().parents[2]
_OUTPUT_DIR = _PROJECT_ROOT / "results" / "_output_"


class Settings(BaseSettings):
    """Setting aplikasi (divalidasi saat startup)."""

    # ── FastAPI ───────────────────────────────────────────────────────
    app_title: str = "NutriFile API"
    app_version: str = "1.0.0"
    debug: bool = True
    host: str = "0.0.0.0"
    port: int = 8001

    # ── Model weights ─────────────────────────────────────────────────
    weights_dir: Path = _OUTPUT_DIR / "weights"
    coco_weights: Path = _OUTPUT_DIR / "yolov8s-seg.pt"

    # ── Uploads ───────────────────────────────────────────────────────
    upload_dir: Path = _PROJECT_ROOT / "uploads"
    max_image_size_mb: int = 10



    # ── Pipeline defaults ────────────────────────────────────────────
    default_daily_target: float = 2000.0
    default_meals_per_day: int = 3
    confidence_threshold: float = 0.25

    model_config = {
        "env_prefix": "NUTRIFILE_",
        "env_file": ".env",
        "extra": "ignore",
    }

    def weight_path(self, name: str) -> Path:
        return self.weights_dir / name


@lru_cache(maxsize=1)
def get_settings() -> Settings:
    return Settings()
