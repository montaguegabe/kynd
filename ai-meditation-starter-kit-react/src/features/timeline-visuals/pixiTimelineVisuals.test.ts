import type { Container } from "pixi.js";
import { describe, expect, it } from "vitest";

import type { VisualEffectId } from "./effectIds";
import type { EffectFactory } from "./effects";
import { ActiveEffectController } from "./pixiTimelineVisuals";

describe("ActiveEffectController", () => {
  it("destroys the previous effect before creating the next one", () => {
    const callLog: string[] = [];

    const registry: Record<VisualEffectId, EffectFactory> = {
      "calm-breath": () => {
        callLog.push("create:calm-breath");
        return {
          update: () => {},
          resize: () => {},
          destroy: () => {
            callLog.push("destroy:calm-breath");
          },
        };
      },
      "soft-pulse": () => {
        callLog.push("create:soft-pulse");
        return {
          update: () => {},
          resize: () => {},
          destroy: () => {
            callLog.push("destroy:soft-pulse");
          },
        };
      },
      starfield: () => {
        callLog.push("create:starfield");
        return {
          update: () => {},
          resize: () => {},
          destroy: () => {
            callLog.push("destroy:starfield");
          },
        };
      },
    };

    const controller = new ActiveEffectController({} as Container, registry);

    controller.switchTo("calm-breath", 800, 450);
    controller.switchTo("soft-pulse", 800, 450);

    expect(callLog).toEqual([
      "create:calm-breath",
      "destroy:calm-breath",
      "create:soft-pulse",
    ]);
  });

  it("clears the active effect", () => {
    let destroyCount = 0;

    const registry: Record<VisualEffectId, EffectFactory> = {
      "calm-breath": () => ({
        update: () => {},
        resize: () => {},
        destroy: () => {
          destroyCount += 1;
        },
      }),
      "soft-pulse": () => ({ update: () => {}, resize: () => {}, destroy: () => {} }),
      starfield: () => ({ update: () => {}, resize: () => {}, destroy: () => {} }),
    };

    const controller = new ActiveEffectController({} as Container, registry);

    controller.switchTo("calm-breath", 640, 360);
    controller.clear();

    expect(destroyCount).toBe(1);
  });
});
