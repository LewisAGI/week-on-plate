const SERVES_RE = /serves?\s+(\d+(?:\.\d+)?)/i;
const QTY_LINE_RE =
  /^\s*(?:[-*•]\s*)?(\d+(?:\.\d+)?)\s*(kg|g|ml|l|tbsp|tsp|cups?|cloves?|x)?\s+(.+?)\s*$/i;
const BARE_BULLET_RE = /^\s*[-*•]\s+(.+?)\s*$/;

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
      ingredients.push({
        name: qty[3].replace(/\s+\(.+\)\s*$/, "").trim(),
        quantity: Number(qty[1]),
        unit: qty[2] ? qty[2].toLowerCase() : "each",
        notes: null,
      });
      continue;
    }
    if (section === "ingredients") {
      const bullet = line.match(BARE_BULLET_RE);
      if (bullet) {
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
        ingredients.push({
          name: qty[3].trim(),
          quantity: Number(qty[1]),
          unit: qty[2] ? qty[2].toLowerCase() : "each",
          notes: null,
        });
      }
    }
  }

  return {
    title,
    summary: url ? `Imported from ${url}` : "Imported from a pasted caption",
    serves,
    minutes: null,
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
