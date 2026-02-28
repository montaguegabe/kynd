from __future__ import annotations

import io
import os
import wave
from importlib import import_module
from typing import Any

from asgiref.sync import sync_to_async
from django.core.files.base import ContentFile
from utils import dedent_strip_format

from ai_meditation_starter_kit_api.meditation_maker.elevenlabs_tts import (
    generate_tts_audio_elevenlabs,
)
from ai_meditation_starter_kit_api.meditation_maker.types import TTSRequest
from ai_meditation_starter_kit_api.meditations.models import Meditation, MeditationAudio

broker = import_module("config.taskiq_config").broker

_DEFAULT_CLAUDE_MODELS = (
    "claude-3-7-sonnet-latest",
    "claude-3-5-sonnet-latest",
    "claude-3-haiku-20240307",
)


def _configured_claude_models() -> tuple[str, ...]:
    configured_list = os.environ.get("MEDITATION_SCRIPT_MODELS", "").strip()
    if configured_list:
        models = tuple(
            model.strip() for model in configured_list.split(",") if model.strip()
        )
        if models:
            return models

    configured_single = os.environ.get("MEDITATION_SCRIPT_MODEL", "").strip()
    if configured_single:
        return (configured_single,)

    return _DEFAULT_CLAUDE_MODELS


def _extract_script_text(content: Any) -> str:
    if isinstance(content, str):
        return content.strip()
    if isinstance(content, list):
        return "\n\n".join(
            block.get("text", "").strip()
            for block in content
            if isinstance(block, dict) and isinstance(block.get("text"), str)
        ).strip()
    return str(content).strip()


async def _generate_script_with_claude(llm_input: str) -> str:
    try:
        anthropic_module = import_module("anthropic")
        langchain_anthropic_module = import_module("langchain_anthropic")
    except ModuleNotFoundError as error:
        msg = (
            "Meditation generation requires optional dependency "
            "'langchain-anthropic'."
        )
        raise RuntimeError(msg) from error

    not_found_error_class = anthropic_module.NotFoundError
    chat_anthropic_class = langchain_anthropic_module.ChatAnthropic

    last_not_found_error: Exception | None = None
    configured_models = _configured_claude_models()
    for model_name in configured_models:
        client = chat_anthropic_class(model=model_name, temperature=0.5)
        try:
            llm_response = await client.ainvoke(llm_input)
            script = _extract_script_text(llm_response.content)
            if script:
                return script
            msg = f"Generated meditation script was empty for model '{model_name}'."
            raise RuntimeError(msg)
        except not_found_error_class as error:
            last_not_found_error = error
            continue

    tried_models = ", ".join(configured_models)
    msg = f"No configured Claude model is available. Tried: {tried_models}"
    raise RuntimeError(msg) from last_not_found_error


@broker.task
async def generate_meditation_assets(meditation_pk: int) -> None:
    meditation = await Meditation.objects.aget(pk=meditation_pk)
    meditation.status = Meditation.Status.PROCESSING
    meditation.error_message = ""
    await meditation.asave(update_fields=["status", "error_message", "updated_at"])

    try:
        llm_input = dedent_strip_format(
            """\
            You are writing one guided loving-kindness (metta) meditation script.
            Return plain narration text only, with no markdown, bullet points, or headings.
            Target a calming pace suitable for about 5 to 8 minutes of spoken audio.
            Include gentle pauses using bracket notation like [2s] where appropriate.
            Keep the tone warm, compassionate, and grounded.

            User description:
            {description}
            """,
            description=meditation.description,
        )
        script = await _generate_script_with_claude(llm_input)

        tts_result = await sync_to_async(generate_tts_audio_elevenlabs)(
            TTSRequest(text=script, languageCode="en-US", outputFormat="wav")
        )
        if not tts_result.audioBytes:
            msg = "TTS provider returned no audio bytes."
            raise RuntimeError(msg)
        audio_bytes = tts_result.audioBytes

        with wave.open(io.BytesIO(audio_bytes), "rb") as wav_file:
            frame_count = wav_file.getnframes()
            frame_rate = wav_file.getframerate()
        duration_ms = int((frame_count / frame_rate) * 1000) if frame_rate else 0

        audio_key = f"audio/{meditation.meditation_id}.wav"
        audio_asset, _ = await MeditationAudio.objects.aget_or_create(audio_key=audio_key)
        await sync_to_async(audio_asset.file.save)(
            f"{meditation.meditation_id}.wav",
            ContentFile(audio_bytes),
            save=False,
        )
        await audio_asset.asave(update_fields=["file", "updated_at"])

        meditation.script = script
        meditation.duration_ms = max(duration_ms, 0)
        meditation.timeline = [{"atMs": 0, "kind": "wav", "file": audio_key}]
        meditation.status = Meditation.Status.READY
        meditation.error_message = ""
        await meditation.asave(
            update_fields=[
                "script",
                "duration_ms",
                "timeline",
                "status",
                "error_message",
                "updated_at",
            ]
        )
    except Exception as error:
        meditation.status = Meditation.Status.FAILED
        meditation.error_message = str(error)[:2000]
        await meditation.asave(update_fields=["status", "error_message", "updated_at"])
        raise
