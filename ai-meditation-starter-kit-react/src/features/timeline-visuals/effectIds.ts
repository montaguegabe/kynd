export const VISUAL_EFFECT_IDS = [
  "calm-breath",
  "soft-pulse",
  "starfield",
] as const;

export type VisualEffectId = (typeof VISUAL_EFFECT_IDS)[number];

export function isVisualEffectId(value: string): value is VisualEffectId {
  return VISUAL_EFFECT_IDS.some((effectId) => effectId === value);
}
