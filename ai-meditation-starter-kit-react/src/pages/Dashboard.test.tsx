import { act, fireEvent, render, screen } from "@testing-library/react";
import React from "react";
import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";

import type { MeditationRecord } from "@/services/meditations";

const testState = vi.hoisted(() => ({
  fetchMeditationsMock: vi.fn(),
  toastMock: vi.fn(),
  visualInstances: [] as Array<{
    switchTo: ReturnType<typeof vi.fn>;
    reset: ReturnType<typeof vi.fn>;
    destroy: ReturnType<typeof vi.fn>;
  }>,
}));

vi.mock("@/components/layouts/ExampleLayout", () => ({
  default: ({ children }: { children: React.ReactNode }) => <div>{children}</div>,
}));

vi.mock("@/services/meditations", () => ({
  fetchMeditations: (...args: unknown[]) => testState.fetchMeditationsMock(...args),
}));

vi.mock("@/hooks/use-toast", () => ({
  useToast: () => ({
    toast: testState.toastMock,
  }),
}));

vi.mock("@/features/timeline-visuals/pixiTimelineVisuals", () => {
  return {
    PixiTimelineVisuals: class MockPixiTimelineVisuals {
      switchTo = vi.fn(async (_effectId: string) => {});
      reset = vi.fn(async () => {});
      destroy = vi.fn();

      constructor(_hostElement: HTMLElement) {
        testState.visualInstances.push(this);
      }
    },
  };
});

import Dashboard from "./Dashboard";

function createMeditation(timeline: unknown): MeditationRecord {
  return {
    id: "timeline-test",
    title: "Timeline Test",
    durationMs: 600,
    timeline,
  };
}

async function flushPromises() {
  await act(async () => {
    await Promise.resolve();
  });
}

describe("Dashboard timeline playback", () => {
  beforeEach(() => {
    vi.useFakeTimers();
    vi.setSystemTime(new Date("2026-02-27T10:00:00Z"));
    testState.fetchMeditationsMock.mockReset();
    testState.toastMock.mockReset();
    testState.visualInstances.length = 0;
  });

  afterEach(() => {
    act(() => {
      vi.runOnlyPendingTimers();
    });
    vi.useRealTimers();
  });

  it("switches Pixi effects when effect events are triggered", async () => {
    testState.fetchMeditationsMock.mockResolvedValue([
      createMeditation([
        { atMs: 10, kind: "effect", effectId: "calm-breath" },
        { atMs: 40, kind: "effect", effectId: "soft-pulse" },
      ]),
    ]);

    render(<Dashboard />);
    await flushPromises();
    await flushPromises();
    expect(screen.getAllByText("Timeline Test").length).toBeGreaterThan(0);

    const playButton = screen.getByRole("button", { name: "Play Timeline" });
    fireEvent.click(playButton);

    const visuals = testState.visualInstances[0];
    expect(visuals).toBeDefined();

    act(() => {
      vi.advanceTimersByTime(10);
    });

    expect(visuals.switchTo).toHaveBeenNthCalledWith(1, "calm-breath");

    act(() => {
      vi.advanceTimersByTime(30);
    });

    expect(visuals.switchTo).toHaveBeenNthCalledWith(2, "soft-pulse");
  });

  it("fails playback when an unknown effect id is encountered", async () => {
    testState.fetchMeditationsMock.mockResolvedValue([
      createMeditation([{ atMs: 10, kind: "effect", effectId: "unknown-effect" }]),
    ]);

    render(<Dashboard />);
    await flushPromises();
    await flushPromises();
    expect(screen.getAllByText("Timeline Test").length).toBeGreaterThan(0);

    const playButton = screen.getByRole("button", { name: "Play Timeline" });
    fireEvent.click(playButton);

    const visuals = testState.visualInstances[0];
    expect(visuals).toBeDefined();

    act(() => {
      vi.advanceTimersByTime(12);
    });

    expect(visuals.switchTo).not.toHaveBeenCalled();
    expect(testState.toastMock).toHaveBeenCalledWith(
      expect.objectContaining({
        title: "Unknown visual effect",
        variant: "destructive",
      })
    );
    expect(playButton).not.toBeDisabled();
  });
});
