const SERVES_RE = /serves?\s+(\d+(?:\.\d+)?)/i;
const MINUTES_RE = /(\d+)\s*(?:mins?|minutes?)\b/i;
const QTY_LINE_RE =
  /^\s*(?:[-*•]\s*)?(\d+(?:\.\d+)?)\s*(kg|g|ml|l|tbsp|tsp|cups?|cloves?|x)?\s+(.+?)\s*$/i;
const BARE_BULLET_RE = /^\s*[-*•]\s+(.+?)\s*$/;
const TIME_OR_TEMP_NAME_RE = /^(mins?|minutes?|hours?|hrs?|secs?|seconds?|°?\s*[cf])$/i;

function looksLikeIngredientName(name) {
  const n = String(name || "").trim();
  if (n.length < 2) return false;
  return !TIME_OR_TEMP_NAME_RE.test(n);
}

function pushIngredient(ingredients, name, quantity, unit) {
  if (!looksLikeIngredientName(name)) return;
  ingredients.push({
    name: String(name).replace(/\s+\(.+\)\s*$/, "").trim(),
    quantity,
    unit,
    notes: null,
  });
}

export function extractFromCaption(text) {
  const raw = String(text || "").replace(/\r\n/g, "\n").trim();
  const lines = raw.split("\n").map((l) => l.trim());
  const nonEmpty = lines.filter(Boolean);
  const url = nonEmpty.find((l) => /^https?:\/\//i.test(l)) || null;

  let title = nonEmpty.find((l) => !/^https?:\/\//i.test(l) && !SERVES_RE.test(l)) || "Imported recipe";
  title = title.replace(/^#+\s*/, "").replace(/[🍽️🥗🍋🔥💪]+/g, "").trim() || "Imported recipe";

  let serves = 2;
  const servesHit = raw.match(SERVES_RE);
  if (servesHit) serves = Math.max(1, Number(servesHit[1]));

  let minutes = null;
  const minutesHit = raw.match(MINUTES_RE);
  if (minutesHit) minutes = Number(minutesHit[1]);

  const ingredients = [];
  const methodLines = [];
  let section = "unknown";
  for (const line of lines) {
    const lower = line.toLowerCase();
    if (/^ingredients?\b/.test(lower)) {
      section = "ingredients";
      continue;
    }
    if (/^(method|steps|directions|instructions)\b/.test(lower)) {
      section = "method";
      continue;
    }
    const qty = line.match(QTY_LINE_RE);
    if (qty) {
      pushIngredient(ingredients, qty[3], Number(qty[1]), qty[2] ? qty[2].toLowerCase() : "each");
      continue;
    }
    if (section === "ingredients") {
      const bullet = line.match(BARE_BULLET_RE);
      if (bullet && looksLikeIngredientName(bullet[1])) {
        ingredients.push({ name: bullet[1], quantity: null, unit: "each", notes: null });
        continue;
      }
    }
    if (section === "method" && line) {
      methodLines.push(line.replace(/^\d+[.)]\s*/, ""));
    }
  }

  if (ingredients.length === 0) {
    for (const line of lines) {
      const qty = line.match(QTY_LINE_RE);
      if (qty) {
        pushIngredient(ingredients, qty[3], Number(qty[1]), qty[2] ? qty[2].toLowerCase() : "each");
      }
    }
  }

  return {
    title,
    summary: url ? `Imported from ${url}` : "Imported from a pasted caption",
    serves,
    minutes,
    method: methodLines.join("\n"),
    ingredients,
    source_text: raw,
    extractor: "heuristic",
  };
}

export function draftFromModelJson(raw, fallbackText) {
  let parsed = raw;
  if (typeof raw === "string") {
    const match = raw.match(/\{[\s\S]*\}/);
    parsed = match ? JSON.parse(match[0]) : null;
  }
  if (!parsed || typeof parsed !== "object") {
    return extractFromCaption(fallbackText);
  }
  const ingredients = Array.isArray(parsed.ingredients)
    ? parsed.ingredients.map((ing) => ({
        name: String(ing.name || "").trim(),
        quantity: ing.quantity == null ? null : Number(ing.quantity),
        unit: String(ing.unit || "each"),
        notes: ing.notes || null,
      })).filter((ing) => ing.name)
    : [];
  return {
    title: String(parsed.title || "Imported recipe").trim(),
    summary: String(parsed.summary || "Imported from a pasted caption"),
    serves: Math.max(1, Number(parsed.serves) || 2),
    minutes: parsed.minutes == null ? null : Number(parsed.minutes),
    method: String(parsed.method || ""),
    ingredients,
    source_text: fallbackText,
    extractor: "workers-ai",
  };
}
