"""
Pydantic models for request and response shapes.
"""

from __future__ import annotations

from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, Field


# ── request models ──────────────────────────────────────────────────────

class NutritionGoal(str, Enum):
    weight_loss = "weight_loss"
    muscle_gain = "muscle_gain"
    maintenance = "maintenance"


class Gender(str, Enum):
    male = "male"
    female = "female"


class ActivityLevel(str, Enum):
    sedentary = "sedentary"
    light = "light"
    moderate = "moderate"
    active = "active"
    very_active = "very_active"



class MealAnalysisBlobRequest(BaseModel):
    """Request model for /analyze_meal/blob — accepts base64-encoded image."""
    image_blob: str = Field(
        ...,
        description="Base64-encoded image data (JPEG/PNG). Can include the data-URI prefix (e.g. 'data:image/png;base64,...') or be raw base64."
    )
    goal: NutritionGoal = Field(..., description="Nutrition goal")
    weight: float = Field(..., gt=0, description="Body weight in kg")
    height: float = Field(..., gt=0, description="Height in cm")
    age: int = Field(..., gt=0, description="Age in years")
    gender: Gender = Field(..., description="Gender: male | female")
    activity_level: ActivityLevel = Field(
        ActivityLevel.moderate,
        description="Activity level"
    )
    daily_target: float = Field(
        0,
        ge=0,
        description="Custom daily calorie target (0 = auto-calculate from biometrics)"
    )


# ══════════════════════════════════════════════════════════════════════
# Response models
# ══════════════════════════════════════════════════════════════════════

class NutritionInfo(BaseModel):
    calories: float
    protein: float
    carbs: float
    fat: float
    sugar: float = 0.0
    sodium: float = 0.0
    fiber: float = 0.0


class IngredientDetail(BaseModel):
    label: str
    confidence: float
    grams: float
    source: str = Field(
        ...,
        description="'detector' | 'ingredient' | 'dish' | 'coco'"
    )
    nutrition: NutritionInfo


class DishPrediction(BaseModel):
    label: str
    confidence: float
    top_candidates: List[dict] = Field(
        default_factory=list,
        description="Top-3 dish classification candidates with probabilities"
    )


class PortionEstimate(BaseModel):
    size: str = Field(..., description="'small' | 'medium' | 'large'")
    grams: float
    area_cm2: float
    method: str


class MealData(BaseModel):
    dish_prediction: Optional[DishPrediction] = None
    ingredients: List[IngredientDetail] = Field(default_factory=list)
    estimated_hidden_ingredients: List[str] = Field(default_factory=list)
    portion_estimate: Optional[PortionEstimate] = None


class GoalAnalysis(BaseModel):
    goal: str
    daily_target_calories: float
    meal_target_calories: float
    protein_target: float
    warnings: List[str] = Field(default_factory=list)


class MealAnalysisResponse(BaseModel):
    status: str = "success"
    meal: MealData
    nutrition_total: NutritionInfo
    goal_analysis: GoalAnalysis
    recommendations: List[str] = Field(default_factory=list)
    detailed_suggestions: List[dict] = Field(default_factory=list)
    explanation: str = ""
    images: dict = Field(default_factory=dict)



class ErrorResponse(BaseModel):
    status: str = "error"
    detail: str
    code: str = "UNKNOWN_ERROR"
