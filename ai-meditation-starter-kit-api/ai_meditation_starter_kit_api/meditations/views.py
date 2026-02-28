from __future__ import annotations

import mimetypes
import secrets
from pathlib import PurePosixPath

from allauth.headless.contrib.rest_framework.authentication import (
    JWTTokenAuthentication,
)
from asgiref.sync import async_to_sync
from django.http import FileResponse
from django.shortcuts import get_object_or_404
from django.urls import reverse
from django.utils import timezone
from django.utils.text import slugify
from rest_framework import viewsets
from rest_framework.exceptions import NotFound
from rest_framework.permissions import IsAuthenticated
from rest_framework.response import Response
from rest_framework.views import APIView

from .models import Meditation, MeditationAudio, MeditationHaptic
from .serializers import MeditationCreateSerializer, MeditationModelSerializer

AUDIO_ROUTE_NAME = "meditations-audio"
HAPTICS_ROUTE_NAME = "meditations-haptics"


def _normalize_asset_key(raw_key: str) -> str:
    normalized = str(PurePosixPath(raw_key.strip().lstrip("/")))
    if normalized in {"", "."}:
        msg = "Asset path is required."
        raise NotFound(msg)

    parts = PurePosixPath(normalized).parts
    if ".." in parts:
        msg = "Asset path is invalid."
        raise NotFound(msg)

    return normalized


def _to_audio_serving_url(request, file_value: str) -> str:
    normalized_key = _normalize_asset_key(file_value)
    serving_key = (
        normalized_key.removeprefix("audio/")
        if normalized_key.startswith("audio/")
        else normalized_key
    )
    url = reverse(AUDIO_ROUTE_NAME, kwargs={"audio_path": serving_key})
    return request.build_absolute_uri(url)


def _to_haptics_serving_url(request, file_value: str) -> str:
    normalized_key = _normalize_asset_key(file_value)
    serving_key = (
        normalized_key.removeprefix("haptics/")
        if normalized_key.startswith("haptics/")
        else normalized_key
    )
    url = reverse(HAPTICS_ROUTE_NAME, kwargs={"haptic_path": serving_key})
    return request.build_absolute_uri(url)


def _rewrite_timeline_asset_urls(request, timeline: object) -> object:
    if not isinstance(timeline, list):
        return timeline

    updated_timeline: list[object] = []
    for entry in timeline:
        if not isinstance(entry, dict):
            updated_timeline.append(entry)
            continue

        kind = entry.get("kind")
        file_value = entry.get("file")
        if (
            kind == "wav"
            and isinstance(file_value, str)
            and file_value
            and not file_value.startswith("http://")
            and not file_value.startswith("https://")
        ):
            updated_entry = dict(entry)
            updated_entry["file"] = _to_audio_serving_url(request, file_value)
            updated_timeline.append(updated_entry)
            continue
        if (
            kind == "ahap"
            and isinstance(file_value, str)
            and file_value
            and not file_value.startswith("http://")
            and not file_value.startswith("https://")
        ):
            updated_entry = dict(entry)
            updated_entry["file"] = _to_haptics_serving_url(request, file_value)
            updated_timeline.append(updated_entry)
            continue

        updated_timeline.append(entry)

    return updated_timeline


def _rewrite_payload_asset_urls(
    request, payload: dict[str, object]
) -> dict[str, object]:
    updated_payload = dict(payload)
    updated_payload["timeline"] = _rewrite_timeline_asset_urls(
        request, payload.get("timeline")
    )
    return updated_payload


def _resolve_model_audio_asset(audio_key: str) -> MeditationAudio:
    normalized_key = _normalize_asset_key(audio_key)
    audio_asset = MeditationAudio.objects.filter(audio_key=normalized_key).first()
    if audio_asset is not None:
        return audio_asset

    prefixed_key = f"audio/{normalized_key}"
    if not normalized_key.startswith("audio/"):
        audio_asset = MeditationAudio.objects.filter(audio_key=prefixed_key).first()
    if audio_asset is not None:
        return audio_asset

    if normalized_key.startswith("audio/"):
        unprefixed_key = normalized_key.removeprefix("audio/")
        audio_asset = MeditationAudio.objects.filter(audio_key=unprefixed_key).first()
    if audio_asset is not None:
        return audio_asset

    msg = "Audio file not found."
    raise NotFound(msg)


def _resolve_model_haptic_asset(haptic_key: str):
    normalized_key = _normalize_asset_key(haptic_key)
    haptic_asset = MeditationHaptic.objects.filter(haptic_key=normalized_key).first()
    if haptic_asset is not None:
        return haptic_asset

    prefixed_key = f"haptics/{normalized_key}"
    if not normalized_key.startswith("haptics/"):
        haptic_asset = MeditationHaptic.objects.filter(haptic_key=prefixed_key).first()
    if haptic_asset is not None:
        return haptic_asset

    if normalized_key.startswith("haptics/"):
        unprefixed_key = normalized_key.removeprefix("haptics/")
        haptic_asset = MeditationHaptic.objects.filter(
            haptic_key=unprefixed_key
        ).first()
    if haptic_asset is not None:
        return haptic_asset

    msg = "Haptic file not found."
    raise NotFound(msg)


def _build_meditation_title(description: str) -> str:
    compact_description = " ".join(description.split())
    if not compact_description:
        return "Loving-Kindness Meditation"
    title = f"Metta: {compact_description[:120]}"
    return title[:255]


def _build_meditation_id(description: str) -> str:
    slug_base = slugify(description)[:64] or "metta-meditation"
    while True:
        candidate = (
            f"{slug_base}-"
            f"{timezone.now().strftime('%Y%m%d%H%M%S')}-"
            f"{secrets.token_hex(2)}"
        )
        if not Meditation.objects.filter(meditation_id=candidate).exists():
            return candidate


class MeditationViewSet(viewsets.ViewSet):
    authentication_classes = [JWTTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def list(self, request):
        serializer = MeditationModelSerializer(Meditation.objects.all(), many=True)
        payload = [
            _rewrite_payload_asset_urls(request, dict(item)) for item in serializer.data
        ]
        return Response(payload)

    def retrieve(self, request, pk=None):
        if not pk:
            msg = "Meditation id is required."
            raise NotFound(msg)

        meditation = get_object_or_404(Meditation, meditation_id=pk)
        serializer = MeditationModelSerializer(meditation)
        payload = _rewrite_payload_asset_urls(request, dict(serializer.data))
        return Response(payload)

    def create(self, request):
        create_serializer = MeditationCreateSerializer(data=request.data)
        create_serializer.is_valid(raise_exception=True)
        description = create_serializer.validated_data["description"]

        meditation = Meditation.objects.create(
            meditation_id=_build_meditation_id(description),
            title=_build_meditation_title(description),
            description=description,
            script="",
            status=Meditation.Status.PENDING,
            error_message="",
            duration_ms=0,
            timeline=[],
        )

        from .tasks.generate_meditation_assets import generate_meditation_assets

        async_to_sync(generate_meditation_assets.kiq)(meditation.pk)

        serializer = MeditationModelSerializer(meditation)
        payload = _rewrite_payload_asset_urls(request, dict(serializer.data))
        return Response(payload, status=201)


class MeditationAudioView(APIView):
    authentication_classes = [JWTTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request, audio_path: str):
        audio_asset = _resolve_model_audio_asset(audio_path)
        content_type = (
            mimetypes.guess_type(audio_asset.file.name)[0] or "application/octet-stream"
        )
        return FileResponse(audio_asset.file.open("rb"), content_type=content_type)


class MeditationHapticView(APIView):
    authentication_classes = [JWTTokenAuthentication]
    permission_classes = [IsAuthenticated]

    def get(self, request, haptic_path: str):
        haptic_asset = _resolve_model_haptic_asset(haptic_path)
        content_type = (
            mimetypes.guess_type(haptic_asset.file.name)[0] or "application/json"
        )
        return FileResponse(haptic_asset.file.open("rb"), content_type=content_type)
