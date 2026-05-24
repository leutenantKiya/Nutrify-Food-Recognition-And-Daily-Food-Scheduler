from __future__ import annotations

import base64
import logging
import re
from mimetypes import guess_extension
from pathlib import Path

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.models.schemas import MealAnalysisResponse, MealAnalysisBlobRequest, ErrorResponse
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
    # validasi gambar
    if not image.content_type or not image.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail="File must be an image (JPEG, PNG, etc.)",
        )

    # validasi field form
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

    # baca bytes gambar
    image_bytes = await image.read()
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded image is empty.")

    ext = Path(image.filename or "").suffix or guess_extension(image.content_type) or ".jpg"

    # jalankan pipeline
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


# ── endpoint blob (base64 JSON) ────────────────────────────────────



def _decode_image_blob(image_blob: str) -> tuple[bytes, str]:
    """
    Decode a base64 image string.

    Supports:
      - Raw base64 string
      - Data URI format: data:image/png;base64,iVBOR...

    Returns (image_bytes, file_extension).
    """
    ext = ".jpg"  # default

    # Strip data-URI prefix if present (e.g. "data:image/png;base64,")
    data_uri_match = re.match(
        r"^data:image/(?P<fmt>[a-zA-Z0-9.+-]+);base64,", image_blob
    )
    if data_uri_match:
        fmt = data_uri_match.group("fmt").lower()
        ext = f".{fmt}" if not fmt.startswith(".") else fmt
        # Normalize common formats
        if ext in (".jpeg", ".jpg"):
            ext = ".jpg"
        elif ext == ".png":
            ext = ".png"
        image_blob = image_blob[data_uri_match.end():]

    try:
        image_bytes = base64.b64decode(image_blob, validate=True)
    except Exception:
        raise HTTPException(
            status_code=400,
            detail="Invalid base64 image data. Ensure the image_blob field contains valid base64-encoded image bytes.",
        )

    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Decoded image is empty.")

    return image_bytes, ext


@router.post(
    "/analyze_meal/blob",
    response_model=MealAnalysisResponse,
    responses={
        400: {"model": ErrorResponse, "description": "Invalid input"},
        422: {"model": ErrorResponse, "description": "Validation error"},
        500: {"model": ErrorResponse, "description": "Pipeline error"},
    },
    summary="Analyze a food image (base64 blob)",
    description=(
        "Submit a food photo as a base64-encoded blob in a JSON body, "
        "along with user biometrics and nutrition goal. "
        "Returns the same structured analysis as /analyze_meal. "
        "Ideal for mobile clients or frontends that already hold the image in memory."
    ),
)
async def analyze_meal_blob_endpoint(body: MealAnalysisBlobRequest):
    """
    Analyze a meal from a base64-encoded image blob.

    The `image_blob` field can be either:
      - Raw base64: `/9j/4AAQSkZ...`
      - Data URI:   `data:image/jpeg;base64,/9j/4AAQSkZ...`
    """
    # ── Decode base64 image ───────────────────────────────────────────
    image_bytes, ext = _decode_image_blob(body.image_blob)

    # jalankan pipeline
    try:
        result = analyze_meal(
            image_bytes=image_bytes,
            goal=body.goal.value,
            weight=body.weight,
            height=body.height,
            age=body.age,
            gender=body.gender.value,
            activity_level=body.activity_level.value,
            daily_target=body.daily_target if body.daily_target > 0 else None,
            ext=ext,
        )
        return result

    except ValueError as e:
        logger.error(f"Validation error in blob pipeline: {e}")
        raise HTTPException(status_code=400, detail=str(e))

    except Exception as e:
        logger.exception("Blob pipeline failed")
        raise HTTPException(
            status_code=500,
            detail=f"Analysis pipeline failed: {str(e)}",
        )

