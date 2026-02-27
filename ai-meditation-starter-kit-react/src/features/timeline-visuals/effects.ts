import { Container, Graphics, Sprite, Texture } from "pixi.js";

import { VisualEffectId } from "./effectIds";

export interface RunningEffect {
  update(deltaMs: number): void;
  resize(width: number, height: number): void;
  destroy(): void;
}

export interface EffectFactoryContext {
  stage: Container;
  width: number;
  height: number;
}

export type EffectFactory = (context: EffectFactoryContext) => RunningEffect;

function createCalmBreathEffect(context: EffectFactoryContext): RunningEffect {
  const root = new Container();
  context.stage.addChild(root);

  const aura = new Graphics()
    .circle(0, 0, 170)
    .fill({ color: 0x8ecae6, alpha: 0.35 });
  const core = new Graphics()
    .circle(0, 0, 120)
    .fill({ color: 0x219ebc, alpha: 0.9 });

  root.addChild(aura);
  root.addChild(core);

  let elapsedMs = 0;

  const resize = (width: number, height: number) => {
    root.position.set(width / 2, height / 2);
  };

  resize(context.width, context.height);

  return {
    update(deltaMs: number) {
      elapsedMs += deltaMs;
      const breathProgress = (Math.sin((elapsedMs / 1900) * Math.PI * 2) + 1) / 2;

      core.scale.set(0.8 + breathProgress * 0.22);
      core.alpha = 0.68 + breathProgress * 0.26;

      aura.scale.set(0.95 + breathProgress * 0.45);
      aura.alpha = 0.2 + breathProgress * 0.35;

      root.rotation = Math.sin(elapsedMs / 3200) * 0.03;
    },
    resize,
    destroy() {
      root.destroy({ children: true });
    },
  };
}

function createSoftPulseEffect(context: EffectFactoryContext): RunningEffect {
  const root = new Container();
  context.stage.addChild(root);

  const centerGlow = new Graphics()
    .circle(0, 0, 70)
    .fill({ color: 0xf4a261, alpha: 0.8 });
  root.addChild(centerGlow);

  const rings = [0, 1, 2].map((index) => {
    const ring = new Graphics().circle(0, 0, 90).stroke({
      width: 6,
      color: index % 2 === 0 ? 0xe76f51 : 0xf4a261,
    });

    ring.alpha = 0;
    root.addChild(ring);
    return ring;
  });

  let elapsedMs = 0;

  const resize = (width: number, height: number) => {
    root.position.set(width / 2, height / 2);
  };

  resize(context.width, context.height);

  return {
    update(deltaMs: number) {
      elapsedMs += deltaMs;

      const glowProgress = (Math.sin((elapsedMs / 1400) * Math.PI * 2) + 1) / 2;
      centerGlow.scale.set(0.88 + glowProgress * 0.26);
      centerGlow.alpha = 0.45 + glowProgress * 0.4;

      rings.forEach((ring, index) => {
        const phase = ((elapsedMs + index * 450) % 1800) / 1800;
        ring.scale.set(0.45 + phase * 1.15);
        ring.alpha = Math.max(0, 1 - phase) * 0.75;
      });
    },
    resize,
    destroy() {
      root.destroy({ children: true });
    },
  };
}

interface StarParticle {
  sprite: Sprite;
  velocityX: number;
  velocityY: number;
  twinkleOffset: number;
}

function createStarfieldEffect(context: EffectFactoryContext): RunningEffect {
  const root = new Container();
  context.stage.addChild(root);

  let width = context.width;
  let height = context.height;
  let elapsedMs = 0;

  const stars: StarParticle[] = Array.from({ length: 90 }, (_, index) => {
    const sprite = new Sprite(Texture.WHITE);
    const size = 1.5 + Math.random() * 3;

    sprite.tint = index % 3 === 0 ? 0xd5f2ff : index % 3 === 1 ? 0xbde0fe : 0xffffff;
    sprite.alpha = 0.35 + Math.random() * 0.55;
    sprite.width = size;
    sprite.height = size;
    sprite.position.set(Math.random() * width, Math.random() * height);

    root.addChild(sprite);

    return {
      sprite,
      velocityX: -0.01 - Math.random() * 0.03,
      velocityY: 0.01 + Math.random() * 0.05,
      twinkleOffset: Math.random() * Math.PI * 2,
    };
  });

  return {
    update(deltaMs: number) {
      elapsedMs += deltaMs;

      stars.forEach((star) => {
        star.sprite.x += star.velocityX * deltaMs;
        star.sprite.y += star.velocityY * deltaMs;

        if (star.sprite.x < -5) {
          star.sprite.x = width + 5;
        }

        if (star.sprite.y > height + 5) {
          star.sprite.y = -5;
        }

        const twinkle = (Math.sin(elapsedMs * 0.003 + star.twinkleOffset) + 1) / 2;
        star.sprite.alpha = 0.2 + twinkle * 0.7;
      });
    },
    resize(nextWidth: number, nextHeight: number) {
      width = nextWidth;
      height = nextHeight;
    },
    destroy() {
      root.destroy({ children: true });
    },
  };
}

export const EFFECT_REGISTRY: Record<VisualEffectId, EffectFactory> = {
  "calm-breath": createCalmBreathEffect,
  "soft-pulse": createSoftPulseEffect,
  starfield: createStarfieldEffect,
};
