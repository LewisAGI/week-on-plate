import { canonicalUnit, normalizeName } from "./shopping.js";

const QTY_LINE_RE =
  /^\s*(?:[-*•]\s*)?(\d+(?:\.\d+)?)\s*(kg|g|ml|l|tbsp|tsp|cups?|cloves?|x)?\s+(.+?)\s*$/i;
const SKIP_LINE_RE = /^(buy|shopping list|cupboard|already have|groceries|items?)\b/i;

/** Parse a typed or OCR'd shopping list into cupboard-shaped items. */
export function parseShoppingListText(text) {
  const items = [];
  for (const raw of String(text || "").replace(/\r\n/g, "\n").split("\n")) {
    const line = raw.trim();
    if (!line || SKIP_LINE_RE.test(line)) continue;
    const qty = line.match(QTY_LINE_RE);
    if (qty && String(qty[3] || "").trim().length >= 2) {
      items.push({
        name: qty[3].trim(),
        quantity: Number(qty[1]),
        unit: qty[2] ? qty[2].toLowerCase() : "each",
      });
      continue;
    }
    const bare = line.replace(/^[-*•]\s*/, "").replace(/^\d+[.)]\s*/, "").trim();
    if (bare.length >= 2) items.push({ name: bare, quantity: null, unit: "each" });
  }
  return items;
}

export const COLD_START_STAPLES = [
  { name: "Olive oil", unit: "ml", quantity: 250 },
  { name: "Salt", unit: "g", quantity: 200 },
  { name: "Black pepper", unit: "g", quantity: 50 },
  { name: "Garlic", unit: "each", quantity: 1 },
  { name: "Onions", unit: "each", quantity: 3 },
  { name: "Tinned tomatoes", unit: "g", quantity: 400 },
  { name: "Pasta", unit: "g", quantity: 500 },
  { name: "Rice", unit: "g", quantity: 500 },
  { name: "Oats", unit: "g", quantity: 500 },
  { name: "Eggs", unit: "each", quantity: 6 },
  { name: "Butter", unit: "g", quantity: 250 },
  { name: "Plain flour", unit: "g", quantity: 500 },
  { name: "Stock cubes", unit: "each", quantity: 8 },
  { name: "Soy sauce", unit: "ml", quantity: 150 },
  { name: "Honey", unit: "g", quantity: 200 },
  { name: "Lemons", unit: "each", quantity: 2 },
];

export function suggestAdjustments(recipeIngredients, cupboard) {
  const stock = cupboard || [];
  const suggestions = [];
  for (const ing of recipeIngredients || []) {
    const n = normalizeName(ing.name);
    const unit = canonicalUnit(ing.unit).unit;
    const match = stock.find(
      (c) => normalizeName(c.name) === n && canonicalUnit(c.unit).unit === unit,
    );
    const used = ing.quantity == null ? null : Number(ing.quantity);
    if (!match) {
      suggestions.push({
        name: ing.name,
        unit,
        action: "none",
        reason: "not in the cupboard",
        used,
      });
      continue;
    }
    if (used == null || match.quantity == null) {
      suggestions.push({
        id: match.id,
        name: match.name,
        unit,
        action: "untick",
        reason: "used this meal — untick if the pack is finished",
        used,
        remaining: 0,
      });
    } else {
      const remaining = Math.max(0, Math.round((Number(match.quantity) - used) * 1000) / 1000);
      suggestions.push({
        id: match.id,
        name: match.name,
        unit,
        action: remaining === 0 ? "untick" : "decrement",
        reason: remaining === 0 ? "that finishes the pack" : "reduce what is left",
        used,
        remaining,
      });
    }
  }
  return suggestions;
}

export function applyAdjustment(item, suggestion) {
  if (!item) return null;
  if (suggestion.action === "untick") {
    return { ...item, in_stock: 0, quantity: 0 };
  }
  if (suggestion.action === "decrement") {
    return { ...item, in_stock: 1, quantity: suggestion.remaining };
  }
  return item;
}
