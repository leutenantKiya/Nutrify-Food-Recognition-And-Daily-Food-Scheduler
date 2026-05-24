"""
POST /chat — AI nutrition chat endpoint.

Two modes:
  1. Pure text chat — user asks nutrition questions
  2. Context-aware chat — user attaches a previous /analyze_meal response
     so the AI can reference specific foods, calories, etc.

This endpoint proxies to an external LLM (Gemini) with a nutrition-focused
system prompt and conversation history support.
"""

from __future__ import annotations

import json
import logging
from mimetypes import guess_extension
from pathlib import Path
from typing import Optional

from fastapi import APIRouter, File, Form, HTTPException, UploadFile

from app.models.schemas import ChatRequest, ChatMessage, ChatResponse, ErrorResponse
from app.services.chat_service import chat
from app.services.meal_service import analyze_meal

logger = logging.getLogger("nutrifile.chat")

router = APIRouter(tags=["Chat"])


@router.post(
    "/chat",
    response_model=ChatResponse,
    responses={
        400: {"model": ErrorResponse, "description": "Invalid input"},
        500: {"model": ErrorResponse, "description": "Chat service error"},
    },
    summary="Chat with NutriFile AI",
    description=(
        "Send a text message to the NutriFile nutrition assistant. "
        "Optionally attach conversation history and/or meal analysis context."
    ),
)
async def chat_endpoint(
    message: str = Form(..., description="User message text"),
    history: str = Form("[]", description="JSON array of previous messages [{role, content}]"),
    meal_context: str = Form("null", description="JSON object — previous /analyze_meal response for context"),
    image: Optional[UploadFile] = File(None, description="Optional food photo for inline analysis"),
    # Biometrics for inline image analysis (only needed when image is attached)
    goal: str = Form("maintenance", description="Nutrition goal"),
    weight: float = Form(70, description="Weight in kg"),
    height: float = Form(170, description="Height in cm"),
    age: int = Form(25, description="Age in years"),
    gender: str = Form("male", description="Gender"),
    activity_level: str = Form("moderate", description="Activity level"),
):
    # ── Parse history ─────────────────────────────────────────────────
    try:
        history_list = json.loads(history)
        parsed_history = [
            ChatMessage(role=msg["role"], content=msg["content"])
            for msg in history_list
        ]
    except (json.JSONDecodeError, KeyError, TypeError):
        parsed_history = []

    # ── Parse meal_context ────────────────────────────────────────────
    try:
        parsed_context = json.loads(meal_context)
    except (json.JSONDecodeError, TypeError):
        parsed_context = None

    # ── Handle inline image analysis ──────────────────────────────────
    # If the user sends a photo through chat (from the camera nav bar),
    # we first run analyze_meal, then pass the result as context to the chat.
    if image is not None and image.content_type and image.content_type.startswith("image/"):
        try:
            image_bytes = await image.read()
            if len(image_bytes) > 0:
                ext = Path(image.filename or "").suffix or guess_extension(image.content_type) or ".jpg"
                analysis_result = analyze_meal(
                    image_bytes=image_bytes,
                    goal=goal,
                    weight=weight,
                    height=height,
                    age=age,
                    gender=gender,
                    activity_level=activity_level,
                    ext=ext,
                )
                # Use the analysis result as context for the chat
                parsed_context = analysis_result.model_dump()

                # If user didn't provide a specific message, generate one
                if not message or message.strip().lower() in ("analyze", "analyze this", "what is this"):
                    message = "Please analyze this meal and give me your assessment."

        except Exception as e:
            logger.warning(f"Inline image analysis failed, proceeding with text-only chat: {e}")

    # ── Build chat request ────────────────────────────────────────────
    chat_request = ChatRequest(
        message=message,
        history=parsed_history,
        meal_context=parsed_context,
    )

    # ── Call chat service ─────────────────────────────────────────────
    try:
        result = await chat(chat_request)
        return result
    except Exception as e:
        logger.exception("Chat service failed")
        raise HTTPException(
            status_code=500,
            detail=f"Chat service error: {str(e)}",
        )
