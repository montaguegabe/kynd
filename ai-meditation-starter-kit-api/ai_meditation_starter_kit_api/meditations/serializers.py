from __future__ import annotations

from config.serializers import BaseModelSerializer
from rest_framework import serializers

from .models import Meditation


class MeditationModelSerializer(BaseModelSerializer):
    id = serializers.SlugField(source="meditation_id")
    durationMs = serializers.IntegerField(source="duration_ms", min_value=0)  # noqa: N815
    timeline = serializers.JSONField()
    script = serializers.CharField(allow_blank=True)
    description = serializers.CharField(allow_blank=True)

    class Meta:
        model = Meditation
        fields = [
            "id",
            "title",
            "durationMs",
            "timeline",
            "status",
            "description",
            "script",
        ]


class MeditationCreateSerializer(serializers.Serializer):
    description = serializers.CharField(trim_whitespace=True, allow_blank=False)
