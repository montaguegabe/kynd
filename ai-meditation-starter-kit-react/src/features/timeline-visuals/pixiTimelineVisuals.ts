import { Application, Container, Ticker } from "pixi.js";

import { VisualEffectId } from "./effectIds";
import {
  EFFECT_REGISTRY,
  EffectFactory,
  EffectFactoryContext,
  RunningEffect,
} from "./effects";

export class ActiveEffectController {
  private runningEffect: RunningEffect | null = null;

  constructor(
    private readonly stage: Container,
    private readonly registry: Record<VisualEffectId, EffectFactory> = EFFECT_REGISTRY
  ) {}

  switchTo(effectId: VisualEffectId, width: number, height: number): void {
    this.clear();

    const createEffect = this.registry[effectId];
    this.runningEffect = createEffect({
      stage: this.stage,
      width,
      height,
    });
  }

  update(deltaMs: number): void {
    this.runningEffect?.update(deltaMs);
  }

  resize(width: number, height: number): void {
    this.runningEffect?.resize(width, height);
  }

  clear(): void {
    if (!this.runningEffect) {
      return;
    }

    const effect = this.runningEffect;
    this.runningEffect = null;
    effect.destroy();
  }
}

export class PixiTimelineVisuals {
  private app: Application | null = null;
  private effectController: ActiveEffectController | null = null;
  private isDestroyed = false;
  private knownWidth = 0;
  private knownHeight = 0;

  private readonly initializePromise: Promise<void>;

  private readonly tickHandler = (ticker: Ticker) => {
    if (!this.app || !this.effectController) {
      return;
    }

    const width = this.app.screen.width;
    const height = this.app.screen.height;

    if (width !== this.knownWidth || height !== this.knownHeight) {
      this.knownWidth = width;
      this.knownHeight = height;
      this.effectController.resize(width, height);
    }

    this.effectController.update(Math.max(0, ticker.deltaMS));
  };

  constructor(private readonly hostElement: HTMLElement) {
    this.initializePromise = this.initialize();
  }

  async switchTo(effectId: VisualEffectId): Promise<void> {
    await this.initializePromise;

    if (!this.app || !this.effectController || this.isDestroyed) {
      return;
    }

    this.effectController.switchTo(
      effectId,
      this.app.screen.width,
      this.app.screen.height
    );
  }

  async reset(): Promise<void> {
    await this.initializePromise;
    this.effectController?.clear();
  }

  destroy(): void {
    this.isDestroyed = true;

    void this.initializePromise.then(() => {
      if (!this.app) {
        return;
      }

      this.effectController?.clear();
      this.effectController = null;

      this.app.ticker.remove(this.tickHandler);
      this.app.destroy({ removeView: true }, true);
      this.app = null;

      this.hostElement.replaceChildren();
    });
  }

  private async initialize(): Promise<void> {
    const app = new Application();

    await app.init({
      antialias: true,
      backgroundAlpha: 0,
      resizeTo: this.hostElement,
    });

    if (this.isDestroyed) {
      app.destroy({ removeView: true }, true);
      return;
    }

    this.hostElement.replaceChildren(app.canvas);

    this.app = app;
    this.knownWidth = app.screen.width;
    this.knownHeight = app.screen.height;
    this.effectController = new ActiveEffectController(app.stage);

    app.ticker.add(this.tickHandler);
  }
}

export type { EffectFactoryContext };
