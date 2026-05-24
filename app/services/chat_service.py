"""
Chat service — proxies user messages to an external LLM API.

Supports:
  - Standalone conversational chat about nutrition
  - Context-aware chat (meal analysis results attached)
  - Conversation history for multi-turn dialogues
"""

from __future__ import annotations

import httpx
import json
from typing import Optional

from app.core.settings import get_settings
from app.models.schemas import ChatRequest, ChatResponse


# ── System prompt for the nutrition assistant ─────────────────────────

SYSTEM_PROMPT = """You are NutriFile AI, a friendly and knowledgeable nutrition assistant.

Your capabilities:
- Analyze food and nutrition information
- Provide dietary advice based on user goals (weight loss, muscle gain, maintenance)
- Answer questions about ingredients, calories, macros, and meal planning
- Give practical cooking and meal prep suggestions
- Explain nutritional concepts in simple terms

Guidelines:
- Be concise but helpful (2-4 sentences for simple questions, more for complex ones)
- Use metric units (grams, kcal) by default
- When meal analysis context is provided, reference the specific foods and nutrition data
- Always be supportive and non-judgmental about food choices
- If unsure about specific nutrition data, say so rather than guessing
- Respond in the same language the user uses

You must NOT:
- Provide medical advice or diagnose conditions
- Recommend extreme diets or fasting without mentioning to consult a professional
- Make claims about curing diseases through diet
"""


def _build_gemini_payload(request: ChatRequest) -> dict:
    """Build the request payload for Google Gemini API."""
    contents = []

    # Add conversation history
    for msg in request.history:
        contents.append({
            "role": msg.role,
            "parts": [{"text": msg.content}]
        })

    # Build current user message with optional meal context
    user_text = request.message
    if request.meal_context:
        context_json = json.dumps(request.meal_context, indent=2, default=str)
        user_text = (
            f"[Meal Analysis Context]\n{context_json}\n\n"
            f"[User Message]\n{request.message}"
        )

    contents.append({
        "role": "user",
        "parts": [{"text": user_text}]
    })

    return {
        "contents": contents,
        "systemInstruction": {
            "parts": [{"text": SYSTEM_PROMPT}]
        },
        "generationConfig": {
            "temperature": 0.7,
            "maxOutputTokens": 1024,
            "topP": 0.9,
        }
    }


def _extract_suggestions(reply: str) -> list[str]:
    """Generate quick-reply suggestions based on the reply content."""
    suggestions = []

    lower = reply.lower()
    if any(w in lower for w in ["calorie", "kalori", "kcal"]):
        suggestions.append("How can I reduce calories?")
    if any(w in lower for w in ["protein"]):
        suggestions.append("Best protein sources?")
    if any(w in lower for w in ["fiber", "serat"]):
        suggestions.append("How to add more fiber?")
    if any(w in lower for w in ["meal", "makan"]):
        suggestions.append("Suggest a balanced meal")
    if any(w in lower for w in ["weight", "berat"]):
        suggestions.append("Tips for healthy weight management")

    # Always include a generic suggestion
    if not suggestions:
        suggestions = [
            "Tell me more about nutrition",
            "How can I eat healthier?",
        ]

    return suggestions[:3]  # Max 3 suggestions


async def chat(request: ChatRequest) -> ChatResponse:
    """
    Send user message to external LLM and return structured response.

    Falls back to a helpful error message if the API is unreachable.
    """
    settings = get_settings()

    if not settings.chat_api_key:
        return ChatResponse(
            status="error",
            reply="Chat API key is not configured. Please set NUTRIFILE_CHAT_API_KEY environment variable.",
            suggestions=["How do I configure the API key?"],
        )

    url = f"{settings.chat_api_url}?key={settings.chat_api_key}"
    payload = _build_gemini_payload(request)

    try:
        async with httpx.AsyncClient(timeout=30.0) as client:
            resp = await client.post(url, json=payload)
            resp.raise_for_status()
            data = resp.json()

        # Extract text from Gemini response
        candidates = data.get("candidates", [])
        if candidates:
            parts = candidates[0].get("content", {}).get("parts", [])
            reply_text = "".join(p.get("text", "") for p in parts)
        else:
            reply_text = "I couldn't generate a response. Please try again."

        return ChatResponse(
            status="success",
            reply=reply_text.strip(),
            suggestions=_extract_suggestions(reply_text),
        )

    except httpx.HTTPStatusError as e:
        return ChatResponse(
            status="error",
            reply=f"Chat service returned an error: {e.response.status_code}. Please try again later.",
            suggestions=["Try again"],
        )
    except httpx.RequestError as e:
        return ChatResponse(
            status="error",
            reply="Could not reach the chat service. Please check your internet connection.",
            suggestions=["Try again"],
        )
    except Exception as e:
        return ChatResponse(
            status="error",
            reply=f"An unexpected error occurred: {str(e)}",
            suggestions=["Try again"],
        )
