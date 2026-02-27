export interface WavPlaybackEvent {
  atMs: number;
  kind: "wav";
  file: string;
}

export interface EffectPlaybackEvent {
  atMs: number;
  kind: "effect";
  effectId: string;
}

export interface AhapPlaybackEvent {
  atMs: number;
  kind: "ahap";
  file?: string;
}

export interface UnknownPlaybackEvent {
  atMs: number;
  kind: "unknown";
  rawKind: string;
  file?: string;
  effectId?: string;
}

export type PlaybackEvent =
  | WavPlaybackEvent
  | EffectPlaybackEvent
  | AhapPlaybackEvent
  | UnknownPlaybackEvent;

function parseAtMs(value: unknown): number {
  if (typeof value !== "number" || !Number.isFinite(value)) {
    return 0;
  }

  return Math.max(0, value);
}

export function extractPlaybackEvents(timeline: unknown): PlaybackEvent[] {
  if (!Array.isArray(timeline)) {
    return [];
  }

  return timeline
    .filter((entry): entry is Record<string, unknown> => !!entry && typeof entry === "object")
    .map((entry): PlaybackEvent => {
      const atMs = parseAtMs(entry.atMs);
      const rawKind = typeof entry.kind === "string" ? entry.kind : "unknown";
      const file = typeof entry.file === "string" ? entry.file : undefined;
      const effectId = typeof entry.effectId === "string" ? entry.effectId : undefined;

      if (rawKind === "wav" && file) {
        return { atMs, kind: "wav", file };
      }

      if (rawKind === "effect" && effectId) {
        return { atMs, kind: "effect", effectId };
      }

      if (rawKind === "ahap") {
        return { atMs, kind: "ahap", file };
      }

      return {
        atMs,
        kind: "unknown",
        rawKind,
        file,
        effectId,
      };
    })
    .sort((first, second) => first.atMs - second.atMs);
}
