"""
Estimasi porsi makanan dari mask segmentasi.

Caranya:
  1. Asumsikan foto dari atas, di atas permukaan makan biasa.
  2. Ambil area polygon mask (koordinat ternormalisasi).
  3. Kalikan dengan area piring referensi (cm2). Default: piring 25 cm
     -> pi * 12.5^2 = 490 cm2, sekitar 70% dari area frame tipikal.
  4. Kalikan dengan density_g_per_cm2 spesifik makanan dari DB nutrisi.

Kalau ada objek referensi (koin, tangan, dll), langkah 3 di-override.

Sengaja dibuat sederhana -- tanpa depth estimation atau rekonstruksi 3D.
Cukup akurat untuk memberikan angka nutrisi yang masuk akal.
"""

from __future__ import annotations

import math
from dataclasses import dataclass
from typing import Optional, Sequence

import numpy as np


# nilai default

# 25 cm diameter standard dinner plate, ~70% frame coverage.
_REF_PLATE_AREA_CM2 = math.pi * (25 / 2) ** 2  # ≈ 490.87 cm^2
_REF_FRAME_FRACTION = 0.70                      # plate ≈ 70% of image area

DEFAULT_FRAME_AREA_CM2 = _REF_PLATE_AREA_CM2 / _REF_FRAME_FRACTION  # ≈ 701 cm^2


@dataclass
class PortionEstimate:
    grams: float
    area_cm2: float
    mask_area_ratio: float            # 0..1 mask coverage of frame
    density_used: float               # g per cm^2
    method: str                       # "default" | "reference_object"

    def to_dict(self) -> dict:
        return {
            "grams": round(self.grams, 1),
            "area_cm2": round(self.area_cm2, 1),
            "mask_area_ratio": round(self.mask_area_ratio, 4),
            "density_g_per_cm2": round(self.density_used, 3),
            "method": self.method,
        }


# ----------------------------------------------------------------------
# Geometry helpers
# ----------------------------------------------------------------------

def polygon_area_normalized(points_xy: Sequence[Sequence[float]]) -> float:
    """
    Shoelace area for a polygon with normalized (0..1) coordinates.
    Returns area in normalized units (0..1).
    """
    pts = np.asarray(points_xy, dtype=np.float64)
    if pts.ndim != 2 or pts.shape[0] < 3:
        return 0.0
    x = pts[:, 0]
    y = pts[:, 1]
    return 0.5 * abs(np.dot(x, np.roll(y, -1)) - np.dot(y, np.roll(x, -1)))


def mask_area_ratio_from_binary(mask: np.ndarray) -> float:
    """Fraction of pixels = 1 in a 2-D binary/uint8 mask."""
    if mask.size == 0:
        return 0.0
    return float((mask > 0).sum()) / float(mask.size)


# ----------------------------------------------------------------------
# Estimator
# ----------------------------------------------------------------------

def estimate_grams(
    mask_area_ratio: float,
    density_g_per_cm2: float,
    frame_area_cm2: Optional[float] = None,
    reference_object_cm2: Optional[float] = None,
    reference_object_mask_ratio: Optional[float] = None,
) -> PortionEstimate:
    """
    Convert a mask area ratio + density into grams.

    Parameters
    ----------
    mask_area_ratio
        Object mask fraction (0..1) of the full image area.
    density_g_per_cm2
        From nutrition DB.
    frame_area_cm2
        Optional override of the total physical area visible in the frame.
        Default = ~701 cm^2 (25 cm plate filling 70% of frame).
    reference_object_cm2, reference_object_mask_ratio
        If both supplied, the physical frame area is back-computed
        (reference_object_cm2 / reference_object_mask_ratio).
    """
    if reference_object_cm2 is not None and reference_object_mask_ratio:
        frame_area_cm2 = reference_object_cm2 / reference_object_mask_ratio
        method = "reference_object"
    else:
        if frame_area_cm2 is None:
            frame_area_cm2 = DEFAULT_FRAME_AREA_CM2
        method = "default"

    area_cm2 = mask_area_ratio * frame_area_cm2
    grams = area_cm2 * density_g_per_cm2

    return PortionEstimate(
        grams=grams,
        area_cm2=area_cm2,
        mask_area_ratio=mask_area_ratio,
        density_used=density_g_per_cm2,
        method=method,
    )
