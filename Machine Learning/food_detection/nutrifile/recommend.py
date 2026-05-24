"""
Mesin rekomendasi berbasis aturan.

Setiap aturan berjalan independen dan menghasilkan saran terstruktur:
- code:        identifier yang machine-readable
- severity:    "info" | "warning" | "alert"
- message:     satu baris yang bisa dibaca manusia
- evidence:    angka-angka yang memicu aturan

Mesinnya sengaja dibuat transparan dan gampang diedit.
Siapapun bisa tambah aturan baru tanpa menyentuh bagian pipeline lain.
"""

from __future__ import annotations

from dataclasses import dataclass
from typing import Dict, List


# target per-makan, diturunkan dari anggaran kalori harian
# rasio makronya mengikuti pedoman umum (US/EU)

def per_meal_targets(daily_kcal: float, meals_per_day: int = 3) -> Dict[str, float]:
    meal_kcal = daily_kcal / meals_per_day
    return {
        # macros in grams
        "kcal":    meal_kcal,
        "carbs":   meal_kcal * 0.50 / 4,        # 50 %E carbs, 4 kcal/g
        "protein": meal_kcal * 0.20 / 4,        # 20 %E protein, 4 kcal/g
        "fat":     meal_kcal * 0.30 / 9,        # 30 %E fat, 9 kcal/g
        "sugar":   25.0,                        # WHO upper bound per meal (~75 g/day)
        "sodium":  766.0,                       # 2300 mg/day / 3 meals
        "fiber":   28.0 / meals_per_day,        # ~28 g daily
    }


# ----------------------------------------------------------------------
# Rule signature
# ----------------------------------------------------------------------

@dataclass
class Suggestion:
    code: str
    severity: str
    message: str
    evidence: dict

    def to_dict(self) -> dict:
        return {
            "code": self.code,
            "severity": self.severity,
            "message": self.message,
            "evidence": self.evidence,
        }


# aturan-aturan individual

def _rule_calorie_target(agg, targets, goal) -> List[Suggestion]:
    out: List[Suggestion] = []
    kcal = agg["kcal"]
    tgt = targets["kcal"]

    over = kcal - tgt
    pct_over = (over / tgt) if tgt > 0 else 0

    if goal == "weight_loss":
        if pct_over > 0.10:
            out.append(Suggestion(
                code="CAL_OVER_WEIGHT_LOSS",
                severity="alert",
                message=(
                    f"This meal has ~{kcal:.0f} kcal, "
                    f"{int(pct_over * 100)}% above your weight-loss target of "
                    f"{tgt:.0f} kcal/meal. Consider reducing portion size."
                ),
                evidence={"kcal": kcal, "target": tgt},
            ))
        elif pct_over > -0.10:
            out.append(Suggestion(
                code="CAL_ON_TARGET",
                severity="info",
                message=f"Calories ({kcal:.0f}) are close to your target ({tgt:.0f}).",
                evidence={"kcal": kcal, "target": tgt},
            ))
    elif goal == "muscle_gain":
        if pct_over < -0.10:
            out.append(Suggestion(
                code="CAL_UNDER_MUSCLE",
                severity="warning",
                message=(
                    f"This meal is only ~{kcal:.0f} kcal vs your target of "
                    f"{tgt:.0f} kcal. Add an extra protein or carb side to support muscle gain."
                ),
                evidence={"kcal": kcal, "target": tgt},
            ))
    else:  # maintenance
        if abs(pct_over) > 0.20:
            direction = "above" if pct_over > 0 else "below"
            out.append(Suggestion(
                code="CAL_OFF_MAINTENANCE",
                severity="warning",
                message=(
                    f"This meal is ~{abs(int(pct_over * 100))}% {direction} a typical "
                    f"maintenance meal ({tgt:.0f} kcal)."
                ),
                evidence={"kcal": kcal, "target": tgt},
            ))

    return out


def _rule_protein(agg, targets, goal) -> List[Suggestion]:
    out: List[Suggestion] = []
    p = agg["protein"]
    tgt = targets["protein"]
    if p < tgt * 0.7:
        msg_extra = " Especially important for muscle gain." if goal == "muscle_gain" else ""
        out.append(Suggestion(
            code="LOW_PROTEIN",
            severity="warning",
            message=(
                f"Only {p:.1f} g protein in this meal vs target {tgt:.1f} g. "
                f"Consider adding chicken, fish, eggs, tofu, or beans.{msg_extra}"
            ),
            evidence={"protein": p, "target": tgt},
        ))
    return out


def _rule_sugar(agg, targets, goal) -> List[Suggestion]:
    out: List[Suggestion] = []
    s = agg["sugar"]
    if s > targets["sugar"] * 1.2:
        out.append(Suggestion(
            code="HIGH_SUGAR",
            severity="alert",
            message=(
                f"Sugar is {s:.1f} g — well above the {targets['sugar']:.0f} g per-meal "
                f"guideline. Cut dessert or sweetened items."
            ),
            evidence={"sugar": s, "target": targets["sugar"]},
        ))
    return out


def _rule_sodium(agg, targets, goal) -> List[Suggestion]:
    out: List[Suggestion] = []
    na = agg["sodium"]
    if na > targets["sodium"] * 1.2:
        out.append(Suggestion(
            code="HIGH_SODIUM",
            severity="alert",
            message=(
                f"Sodium is {na:.0f} mg — high for a single meal "
                f"(target <= {targets['sodium']:.0f} mg). Watch out for cured meats, "
                f"sauces, and salty snacks."
            ),
            evidence={"sodium": na, "target": targets["sodium"]},
        ))
    return out


def _rule_fat(agg, targets, goal) -> List[Suggestion]:
    out: List[Suggestion] = []
    f = agg["fat"]
    if f > targets["fat"] * 1.5:
        out.append(Suggestion(
            code="HIGH_FAT",
            severity="warning",
            message=(
                f"Fat is {f:.1f} g — more than 1.5× the per-meal target "
                f"({targets['fat']:.1f} g)."
            ),
            evidence={"fat": f, "target": targets["fat"]},
        ))
    return out


def _rule_fiber(agg, targets, goal) -> List[Suggestion]:
    out: List[Suggestion] = []
    fi = agg["fiber"]
    if fi < targets["fiber"] * 0.5 and agg["kcal"] > 200:
        out.append(Suggestion(
            code="LOW_FIBER",
            severity="info",
            message=(
                f"Only {fi:.1f} g fiber. Add vegetables, fruit, or whole-grain bread to "
                f"reach the per-meal target (~{targets['fiber']:.1f} g)."
            ),
            evidence={"fiber": fi, "target": targets["fiber"]},
        ))
    return out


def _rule_balance(agg, targets, goal) -> List[Suggestion]:
    out: List[Suggestion] = []
    kcal = agg["kcal"]
    if kcal <= 0:
        return out
    carbs_pct = (agg["carbs"] * 4) / kcal
    prot_pct  = (agg["protein"] * 4) / kcal
    fat_pct   = (agg["fat"] * 9) / kcal

    if carbs_pct > 0.65:
        out.append(Suggestion(
            code="CARB_DOMINANT",
            severity="info",
            message=(
                f"This meal is carb-heavy ({carbs_pct:.0%} of calories from carbs). "
                f"Balance with protein and vegetables."
            ),
            evidence={"carbs_pct": round(carbs_pct, 3)},
        ))
    if fat_pct > 0.45:
        out.append(Suggestion(
            code="FAT_DOMINANT",
            severity="info",
            message=(
                f"This meal is fat-heavy ({fat_pct:.0%} of calories from fat)."
            ),
            evidence={"fat_pct": round(fat_pct, 3)},
        ))
    if prot_pct < 0.10 and kcal > 200:
        out.append(Suggestion(
            code="LOW_PROTEIN_PCT",
            severity="warning",
            message=(
                f"Protein supplies only {prot_pct:.0%} of energy. "
                f"Add a protein source."
            ),
            evidence={"protein_pct": round(prot_pct, 3)},
        ))

    return out


# jalankan semua aturan

RULES = [
    _rule_calorie_target,
    _rule_protein,
    _rule_sugar,
    _rule_sodium,
    _rule_fat,
    _rule_fiber,
    _rule_balance,
]


def recommendations_for(
    aggregated_nutrition: dict,
    goal: str = "maintenance",
    target_kcal: float = 2000.0,
    meals_per_day: int = 3,
) -> List[dict]:
    """Jalankan semua aturan dan return list saran dalam bentuk dict."""
    targets = per_meal_targets(target_kcal, meals_per_day=meals_per_day)

    out: List[Suggestion] = []
    for rule in RULES:
        out.extend(rule(aggregated_nutrition, targets, goal))

    return [s.to_dict() for s in out]
