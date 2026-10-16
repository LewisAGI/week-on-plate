/** Household heads: each adult and each under-18 counts as one plate. */
export function householdHeads(adults, under18s) {
  const a = Math.max(0, Math.trunc(Number(adults) || 0));
  const u = Math.max(0, Math.trunc(Number(under18s) || 0));
  return a + u;
}

/** Scale a recipe written for `serves` people onto the household. */
export function scaleFactor(serves, adults, under18s) {
  const s = Number(serves);
  if (!Number.isFinite(s) || s <= 0) return 1;
  const heads = householdHeads(adults, under18s);
  if (heads <= 0) return 1;
  return heads / s;
}

export function scaleQuantity(quantity, factor) {
  if (quantity == null || quantity === "") return null;
  const q = Number(quantity);
  const f = Number(factor);
  if (!Number.isFinite(q) || !Number.isFinite(f)) return null;
  return Math.round(q * f * 1000) / 1000;
}

export const DEFAULT_ADULTS = 2;
export const DEFAULT_UNDER18S = 0;

export const TEEN_TIP =
  "For teens: consider teenage eating habits. Some eat like adults — count them that way if that is your house.";
