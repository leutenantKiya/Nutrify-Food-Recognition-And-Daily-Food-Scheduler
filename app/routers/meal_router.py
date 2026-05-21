"""
POST /analyze_meal — Multipart food image analysis endpoint.

Accepts:
  - image (UploadFile)
  - goal, weight, height, age, gender, activity_level (Form fields)
  - daily_target (optional Form field)

Returns:
  Structured JSON with meal prediction, ingredients, nutrition,
  goal-aware analysis, recommendations, and annotated image path.
"""

from __future__ import annotations

import logging
from mimetypes import guess_extension
from pathlib import Path

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.models.schemas import MealAnalysisResponse, ErrorResponse
from app.services.meal_service import analyze_meal

logger = logging.getLogger("nutrifile.meal")

router = APIRouter(tags=["Meal Analysis"])


@router.post(
    "/analyze_meal",
    response_model=MealAnalysisResponse,
    responses={
        400: {"model": ErrorResponse, "description": "Invalid input"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Pipeline error"},
    },
    summary="Analyze a food image",
    description=(
        "Upload a food photo along with user biometrics and nutrition goal. "
        "Returns detected dish, visible ingredients, estimated hidden ingredients, "
        "portion estimation, nutrition calculation, goal-aware recommendations, "
        "and an annotated image."
    ),
)
async def analyze_meal_endpoint(
    image: UploadFile = File(..., description="Food photo (JPEG/PNG)"),
    goal: str = Form(..., description="Nutrition goal: weight_loss | muscle_gain | maintenance"),
    weight: float = Form(..., description="Body weight in kg"),
    height: float = Form(..., description="Height in cm"),
    age: int = Form(..., description="Age in years"),
    gender: str = Form(..., description="Gender: male | female"),
    activity_level: str = Form("moderate", description="Activity: sedentary | light | moderate | active | very_active"),
    daily_target: float = Form(0, description="Custom daily calorie target (0 = auto-calculate from biometrics)"),
):
    # ── Validate image ────────────────────────────────────────────────
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail="File must be an image (JPEG, PNG, etc.)",
        )

    # ── Validate form fields ──────────────────────────────────────────
    valid_goals = {"weight_loss", "muscle_gain", "maintenance"}
    if goal not in valid_goals:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid goal '{goal}'. Must be one of: {', '.join(valid_goals)}",
        )

    valid_genders = {"male", "female"}
    if gender not in valid_genders:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid gender '{gender}'. Must be one of: {', '.join(valid_genders)}",
        )

    valid_activity = {"sedentary", "light", "moderate", "active", "very_active"}
    if activity_level not in valid_activity:
        raise HTTPException(
            status_code=400,
            detail=f"Invalid activity_level '{activity_level}'. Must be one of: {', '.join(valid_activity)}",
        )

    if weight <= 0 or height <= 0 or age <= 0:
        raise HTTPException(
            status_code=400,
            detail="weight, height, and age must be positive numbers.",
        )

    # ── Read image bytes ──────────────────────────────────────────────
    image_bytes = await image.read()
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded image is empty.")

    ext = Path(image.filename or "").suffix or guess_extension(image.content_type) or ".jpg"

    # ── Run pipeline ──────────────────────────────────────────────────
    try:
        result = analyze_meal(
            image_bytes=image_bytes,
            goal=goal,
            weight=weight,
            height=height,
            age=age,
            gender=gender,
            activity_level=activity_level,
            daily_target=daily_target if daily_target > 0 else None,
            ext=ext,
        )
        return result

    except ValueError as e:
        logger.error(f"Validation error in pipeline: {e}")
        raise HTTPException(status_code=400, detail=str(e))

    except Exception as e:
        logger.exception("Pipeline failed")
        raise HTTPException(
            status_code=500,
            detail=f"Analysis pipeline failed: {str(e)}",
        )
