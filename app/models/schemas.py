"""
Pydantic models for all request/response shapes.

Designed for clean structured JSON — no flat text logs.
"""

from __future__ import annotations

from enum import Enum
from typing import List, Optional

from pydantic import BaseModel, Field


# ══════════════════════════════════════════════════════════════════════
# Request models
# ══════════════════════════════════════════════════════════════════════

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


class ChatMessage(BaseModel):
    role: str = Field(..., description="'user' or 'model'")
    content: str


class ChatRequest(BaseModel):
    message: str = Field(..., description="User message text")
    history: List[ChatMessage] = Field(
        default_factory=list,
        description="Previous conversation messages"
    )
    # Optional context from a previous meal analysis
    meal_context: Optional[dict] = Field(
        None,
        description="Attach the most recent /analyze_meal response so the model can reference it"
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


class ChatResponse(BaseModel):
    status: str = "success"
    reply: str
    suggestions: List[str] = Field(
        default_factory=list,
        description="Quick-reply suggestions the UI can show as chips"
    )


class ErrorResponse(BaseModel):
    status: str = "error"
    detail: str
    code: str = "UNKNOWN_ERROR"
