"""
Bikin ringkasan makanan yang bisa dibaca manusia.

Input: daftar deteksi + nutrisi agregat + saran.
Output: teks ringkasan untuk UI aplikasi.
"""

from __future__ import annotations

from typing import List


def _format_label(label: str) -> str:
    if not label:
        return "unknown"
    return label.replace("_", " ")


def summarize(
    detections: List,
    aggregated: dict,
    recommendations: List[dict],
    goal: str = "maintenance",
    target_kcal: float = 2000.0,
) -> str:
    lines: List[str] = []

    # ----- Composition -----
    if not detections:
        lines.append("No food items were detected in the image.")
    else:
        lines.append(f"Detected {len(detections)} food region(s):")
        for i, det in enumerate(detections, start=1):
            label_pretty = _format_label(det.label or "unknown")
            grams = det.portion["grams"] if det.portion else 0.0
            kcal  = det.nutrition["kcal"] if det.nutrition else 0.0
            src   = det.label_source or "unknown"
            lines.append(
                f"  {i}. {label_pretty}  ~{grams:.0f} g  ({kcal:.0f} kcal, via {src} head)"
            )

    # ----- Totals -----
    lines.append("")
    lines.append("Estimated total nutrition for this meal:")
    lines.append(
        f"  Calories : {aggregated['kcal']:.0f} kcal\n"
        f"  Carbs    : {aggregated['carbs']:.1f} g\n"
        f"  Protein  : {aggregated['protein']:.1f} g\n"
        f"  Fat      : {aggregated['fat']:.1f} g\n"
        f"  Sugar    : {aggregated['sugar']:.1f} g\n"
        f"  Sodium   : {aggregated['sodium']:.0f} mg\n"
        f"  Fiber    : {aggregated['fiber']:.1f} g\n"
        f"  (≈ {aggregated['total_grams']:.0f} g total estimated food weight)"
    )

    lines.append("")
    lines.append(f"Goal: {goal} | Daily target: {target_kcal:.0f} kcal")

    # ----- Recommendations -----
    if not recommendations:
        lines.append("Recommendations: meal looks well-balanced for your goal.")
    else:
        lines.append("Recommendations:")
        for rec in recommendations:
            sev = rec["severity"].upper()
            lines.append(f"  [{sev}] {rec['message']}")

    return "\n".join(lines)
