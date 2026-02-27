import { describe, expect, it } from "vitest";

import { extractPlaybackEvents } from "./timelineEvents";

describe("extractPlaybackEvents", () => {
  it("sorts events by timestamp and normalizes invalid timestamps", () => {
    const events = extractPlaybackEvents([
      { atMs: 450, kind: "wav", file: "audio/three.wav" },
      { atMs: -40, kind: "effect", effectId: "calm-breath" },
      { atMs: 120, kind: "ahap", file: "haptics/rise.ahap" },
      { atMs: 50, kind: "unknown-kind" },
    ]);

    expect(events.map((event) => event.atMs)).toEqual([0, 50, 120, 450]);
    expect(events[0]).toEqual({ atMs: 0, kind: "effect", effectId: "calm-breath" });
  });

  it("marks invalid effect events as unknown", () => {
    const events = extractPlaybackEvents([
      { atMs: 10, kind: "effect" },
      { atMs: 20, kind: "wav" },
    ]);

    expect(events[0]).toMatchObject({
      atMs: 10,
      kind: "unknown",
      rawKind: "effect",
    });

    expect(events[1]).toMatchObject({
      atMs: 20,
      kind: "unknown",
      rawKind: "wav",
    });
  });

  it("returns an empty array for non-array timelines", () => {
    expect(extractPlaybackEvents(null)).toEqual([]);
    expect(extractPlaybackEvents({})).toEqual([]);
  });
});
