"""
Main entry point for the NutriFile backend.

Two ways to send a food photo:
    POST /analyze_meal       -- multipart form (image file + biometrics)
    POST /analyze_meal/blob  -- JSON body with base64 image
    GET  /                   -- health check
"""

from __future__ import annotations

import base64
import re
import logging
import sys
from enum import Enum
from pathlib import Path
from typing import List, Optional
from uuid import uuid4

from fastapi import FastAPI, HTTPException, File, Form, UploadFile, Response
from fastapi.middleware.cors import CORSMiddleware
from fastapi.staticfiles import StaticFiles
from pydantic import BaseModel, Field

# add project root to sys.path so we can import the nutrifile package
PROJECT_ROOT = Path(__file__).resolve().parent
if str(PROJECT_ROOT) not in sys.path:
    sys.path.insert(0, str(PROJECT_ROOT))

from app.services.meal_service import analyze_meal as run_pipeline_analysis
from app.core.settings import get_settings
from app.models.schemas import MealAnalysisResponse


# ── Logging ───────────────────────────────────────────────────────────
logging.basicConfig(
    level=logging.INFO,
    format="%(asctime)s │ %(name)-20s │ %(levelname)-7s │ %(message)s",
    datefmt="%H:%M:%S",
)
logger = logging.getLogger("nutrifile_main")

# ── Save directory ────────────────────────────────────────────────────
SAVE_DIR = Path(__file__).resolve().parent / "temp_image_POST"
SAVE_DIR.mkdir(parents=True, exist_ok=True)


# local copies of enums (duplicated from schemas.py for the standalone /analyze_meal route)
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
        description="Base64-encoded image data (JPEG/PNG). Can include the data-URI prefix or be raw base64."
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


app = FastAPI(
    title="NutriFile API",
    version="1.2.0",
    description="Food recognition backend. Accepts a photo, runs YOLOv8 + EfficientNet, returns nutrition JSON.",
)

app.add_middleware(
    CORSMiddleware,
    allow_origins=["*"],
    allow_credentials=True,
    allow_methods=["*"],
    allow_headers=["*"],
)

# serve annotated images so the Flutter app can download them
app.mount("/uploads", StaticFiles(directory=str(PROJECT_ROOT / "uploads")), name="uploads")




# ── routes ────────────────────────────────────────────────────────────

@app.post("/analyze_meal", response_model=MealAnalysisResponse, summary="Receive image and details from Flutter and save")
@app.post("/analyze_meal/", response_model=MealAnalysisResponse, include_in_schema=False)
@app.post("/api/v1/analyze_meal", response_model=MealAnalysisResponse, summary="Receive image and details from Flutter and save (API v1)")
@app.post("/api/v1/analyze_meal/", response_model=MealAnalysisResponse, include_in_schema=False)
# typo-tolerant aliases (the Flutter app once shipped with "anaylze_meal")
@app.post("/anaylze_meal", response_model=MealAnalysisResponse, include_in_schema=False)
@app.post("/anaylze_meal/", response_model=MealAnalysisResponse, include_in_schema=False)
@app.post("/api/v1/anaylze_meal", response_model=MealAnalysisResponse, include_in_schema=False)
@app.post("/api/v1/anaylze_meal/", response_model=MealAnalysisResponse, include_in_schema=False)
async def analyze_meal(
    img: Optional[UploadFile] = File(None, description="Food photo via 'img' (JPEG/PNG)"),
    image: Optional[UploadFile] = File(None, description="Food photo via 'image' (JPEG/PNG)"),
    goal: Optional[str] = Form(None, description="Nutrition goal: weight_loss | muscle_gain | maintenance"),
    weight: Optional[float] = Form(None, description="Body weight in kg"),
    height: Optional[float] = Form(None, description="Height in cm"),
    age: Optional[int] = Form(None, description="Age in years"),
    gender: Optional[str] = Form(None, description="Gender: male | female"),
    activity_level: Optional[str] = Form("moderate", description="Activity level"),
    daily_target: Optional[float] = Form(0, description="Custom daily calorie target"),
):
    """
    Terima foto makanan (multipart form) beserta data biometrik pengguna.
    Simpan foto ke temp_image_POST/, jalankan pipeline ML, kembalikan JSON nutrisi.
    """
    logger.info("Menerima request analyze_meal (form-data) dari Flutter...")

    # Flutter bisa kirim lewat field 'img' atau 'image', ambil yang ada
    selected_image = img or image
    if not selected_image:
        raise HTTPException(
            status_code=400,
            detail="Request must contain an image file under the 'img' or 'image' field."
        )

    # cek tipe file
    if not selected_image.content_type or not selected_image.content_type.startswith("image/"):
        raise HTTPException(
            status_code=400,
            detail="File must be an image (JPEG, PNG, etc.)",
        )

    # validasi field form
    if goal is not None:
        valid_goals = {"weight_loss", "muscle_gain", "maintenance"}
        if goal not in valid_goals:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid goal '{goal}'. Must be one of: {', '.join(valid_goals)}",
            )

    if gender is not None:
        valid_genders = {"male", "female"}
        if gender not in valid_genders:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid gender '{gender}'. Must be one of: {', '.join(valid_genders)}",
            )

    if activity_level is not None:
        valid_activity = {"sedentary", "light", "moderate", "active", "very_active"}
        if activity_level not in valid_activity:
            raise HTTPException(
                status_code=400,
                detail=f"Invalid activity_level '{activity_level}'. Must be one of: {', '.join(valid_activity)}",
            )

    if (weight is not None and weight <= 0) or (height is not None and height <= 0) or (age is not None and age <= 0):
        raise HTTPException(
            status_code=400,
            detail="weight, height, and age must be positive numbers.",
        )

    # ── Read image bytes ──────────────────────────────────────────────
    image_bytes = await selected_image.read()
    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Uploaded image is empty.")

    # Determine Extension
    ext = Path(selected_image.filename or "").suffix or ".jpg"
    if ext in (".jpeg", ".jpg"):
        ext = ".jpg"

    # Clean the filename to be safe
    safe_filename = selected_image.filename or f"flutter_upload_{uuid4().hex[:8]}"
    safe_filename = Path(safe_filename).name

    # Strip existing extension and replace/ensure correct one
    if safe_filename.endswith(ext):
        final_filename = f"{Path(safe_filename).stem}_{uuid4().hex[:6]}{ext}"
    else:
        final_filename = f"{safe_filename}_{uuid4().hex[:6]}{ext}"

    filepath = SAVE_DIR / final_filename
    filepath.write_bytes(image_bytes)

    file_info = {
        "filename": final_filename,
        "path": str(filepath),
        "size_bytes": len(image_bytes),
        "size_kb": round(len(image_bytes) / 1024, 2),
        "contentType": selected_image.content_type or "unknown",
    }

    logger.info(f"Image tersimpan: {file_info['filename']} ({file_info['size_kb']} KB)")

    # jalankan pipeline ML
    try:
        user_goal = goal or "maintenance"
        user_weight = weight if (weight is not None and weight > 0) else 70.0
        user_height = height if (height is not None and height > 0) else 170.0
        user_age = age if (age is not None and age > 0) else 25
        user_gender = gender or "male"
        user_activity = activity_level or "moderate"
        user_target = daily_target if (daily_target is not None and daily_target > 0) else 0.0

        logger.info(f"Forwarding image to ML model pipeline...")
        analysis_result = run_pipeline_analysis(
            image_bytes=image_bytes,
            goal=user_goal,
            weight=user_weight,
            height=user_height,
            age=user_age,
            gender=user_gender,
            activity_level=user_activity,
            daily_target=user_target if user_target > 0 else None,
            ext=ext,
        )

        logger.info("ML Pipeline successful! Returning full MealAnalysisResponse JSON.")
        return analysis_result

    except Exception as e:
        logger.exception(f"Error running ML model pipeline: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Analysis pipeline failed: {str(e)}"
        )


@app.post("/analyze_meal/blob", response_model=MealAnalysisResponse, summary="Receive base64 image blob and details from Flutter and save")
@app.post("/analyze_meal/blob/", response_model=MealAnalysisResponse, include_in_schema=False)
@app.post("/api/v1/analyze_meal/blob", response_model=MealAnalysisResponse, summary="Receive base64 image blob and details from Flutter and save (API v1)")
@app.post("/api/v1/analyze_meal/blob/", response_model=MealAnalysisResponse, include_in_schema=False)
# typo-tolerant aliases
@app.post("/anaylze_meal/blob", response_model=MealAnalysisResponse, include_in_schema=False)
@app.post("/anaylze_meal/blob/", response_model=MealAnalysisResponse, include_in_schema=False)
@app.post("/api/v1/anaylze_meal/blob", response_model=MealAnalysisResponse, include_in_schema=False)
@app.post("/api/v1/anaylze_meal/blob/", response_model=MealAnalysisResponse, include_in_schema=False)
async def analyze_meal_blob(body: MealAnalysisBlobRequest):
    """
    Sama seperti /analyze_meal tapi gambar dikirim sebagai string base64 dalam JSON body.
    """
    logger.info("Menerima request analyze_meal (blob) dari Flutter...")

    # Decode the base64 image
    image_blob = body.image_blob
    ext = ".jpg"  # default

    # Strip data-URI prefix if present
    data_uri_match = re.match(
        r"^data:image/(?P<fmt>[a-zA-Z0-9.+-]+);base64,", image_blob
    )
    if data_uri_match:
        fmt = data_uri_match.group("fmt").lower()
        ext = f".{fmt}" if not fmt.startswith(".") else fmt
        if ext in (".jpeg", ".jpg"):
            ext = ".jpg"
        elif ext == ".png":
            ext = ".png"
        image_blob = image_blob[data_uri_match.end():]

    try:
        image_bytes = base64.b64decode(image_blob)
    except Exception as e:
        logger.error(f"Failed to decode base64 'image_blob': {e}")
        raise HTTPException(
            status_code=400,
            detail="Invalid base64 string in 'image_blob' parameter."
        )

    if len(image_bytes) == 0:
        raise HTTPException(status_code=400, detail="Decoded image is empty.")

    # Save to file
    final_filename = f"flutter_blob_{uuid4().hex[:8]}{ext}"
    filepath = SAVE_DIR / final_filename
    filepath.write_bytes(image_bytes)

    logger.info(f"Image blob tersimpan: {final_filename} ({round(len(image_bytes) / 1024, 2)} KB)")

    # jalankan pipeline ML
    try:
        logger.info(f"Forwarding blob image to ML model pipeline...")
        analysis_result = run_pipeline_analysis(
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

        logger.info("ML Blob Pipeline successful! Returning full MealAnalysisResponse JSON.")
        return analysis_result

    except Exception as e:
        logger.exception(f"Error running ML blob model pipeline: {e}")
        raise HTTPException(
            status_code=500,
            detail=f"Analysis pipeline failed: {str(e)}"
        )


# health check
@app.get("/", summary="Health check")
async def root():
    return {
        "name": "NutriFile API (Flutter Friendly)",
        "version": "1.2.0",
        "endpoints": {
            "multipart_form": "POST /analyze_meal",
            "base64_blob": "POST /analyze_meal/blob"
        },
        "save_dir": str(SAVE_DIR),
    }


# kalau dijalankan langsung: python main.py
if __name__ == "__main__":
    import uvicorn
    # Listen on 0.0.0.0 so external devices/emulators can connect
    uvicorn.run("main:app", host="0.0.0.0", port=7777, reload=True)