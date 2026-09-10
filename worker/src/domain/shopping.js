export function normalizeName(name) {
  return String(name || "")
    .toLowerCase()
    .normalize("NFKD")
    .replace(/[^\p{L}\p{N}\s]/gu, " ")
    .replace(/\s+/g, " ")
    .trim()
    .replace(/ies$/i, "y")
    .replace(/oes$/i, "o")
    .replace(/ses$/i, "s")
    .replace(/s$/i, "");
}

export function canonicalUnit(unit) {
  const u = String(unit || "")
    .toLowerCase()
    .trim();
  if (["kg", "kilogram", "kilograms"].includes(u)) return { unit: "g", factor: 1000 };
  if (["l", "litre", "litres", "liter", "liters"].includes(u)) return { unit: "ml", factor: 1000 };
  if (["g", "gram", "grams"].includes(u)) return { unit: "g", factor: 1 };
  if (["ml", "millilitre", "millilitres", "milliliter", "milliliters"].includes(u)) {
    return { unit: "ml", factor: 1 };
  }
  if (["tbsp", "tablespoon", "tablespoons"].includes(u)) return { unit: "ml", factor: 15 };
  if (["tsp", "teaspoon", "teaspoons"].includes(u)) return { unit: "ml", factor: 5 };
  if (["", "x", "each", "unit", "units", "item", "items"].includes(u)) {
    return { unit: "each", factor: 1 };
  }
  return { unit: u, factor: 1 };
}

export function mergeIngredients(items) {
  const map = new Map();
  for (const item of items || []) {
    const rawName = String(item.name || "").trim();
    const normalized = normalizeName(rawName);
    if (!normalized) continue;
    const cu = canonicalUnit(item.unit);
    const qty =
      item.quantity == null || item.quantity === ""
        ? null
        : Number(item.quantity) * cu.factor;
    const key = `${normalized}|${cu.unit}`;
    const prev = map.get(key);
    if (!prev) {
      map.set(key, {
        name: rawName,
        normalized,
        quantity: Number.isFinite(qty) ? qty : null,
        unit: cu.unit,
        notes: item.notes || null,
      });
    } else if (prev.quantity != null && Number.isFinite(qty)) {
      prev.quantity += qty;
    } else if (prev.quantity == null && Number.isFinite(qty)) {
      prev.quantity = qty;
    }
  }
  return [...map.values()].map((row) => ({
    ...row,
    quantity: row.quantity == null ? null : Math.round(row.quantity * 1000) / 1000,
  }));
}

export function subtractCupboard(merged, cupboard) {
  const stock = new Map();
  for (const item of cupboard || []) {
    if (Number(item.in_stock) === 0) continue;
    const key = `${normalizeName(item.name)}|${canonicalUnit(item.unit).unit}`;
    const cu = canonicalUnit(item.unit);
    const qty =
      item.quantity == null || item.quantity === ""
        ? null
        : Number(item.quantity) * cu.factor;
    stock.set(key, Number.isFinite(qty) ? qty : Infinity);
  }

  const buy = [];
  const alreadyHave = [];
  for (const row of merged || []) {
    const key = `${row.normalized}|${row.unit}`;
    const have = stock.has(key) ? stock.get(key) : 0;
    if (have === Infinity || (row.quantity == null && have > 0)) {
      alreadyHave.push({ ...row, covered: row.quantity });
      continue;
    }
    if (row.quantity == null) {
      buy.push({ ...row, still_needed: null });
      continue;
    }
    const needed = Math.max(0, Math.round((row.quantity - have) * 1000) / 1000);
    if (needed === 0) {
      alreadyHave.push({ ...row, covered: row.quantity });
    } else if (have > 0) {
      buy.push({ ...row, still_needed: needed, from_cupboard: have });
    } else {
      buy.push({ ...row, still_needed: needed, from_cupboard: 0 });
    }
  }
  return { buy, already_have: alreadyHave };
}
