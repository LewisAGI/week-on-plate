const NUMBER_PREFIX = /^\s*(?:\d+[.)]\s+|[-*•]\s+)/;

function cleanStep(value) {
  return String(value || "")
    .replace(NUMBER_PREFIX, "")
    .replace(/\s+/g, " ")
    .trim();
}

/** Split a one-line paragraph on sentence boundaries, keeping the closer. */
function splitSentences(text) {
  const raw = String(text || "").trim();
  if (!raw) return [];
  const parts = raw.split(/(?<=[.!?])\s+(?=[A-Z0-9])/);
  const cleaned = parts.map(cleanStep).filter(Boolean);
  return cleaned.length ? cleaned : [raw];
}

/**
 * Turn a stored method string and/or a steps array into numbered display steps.
 * Existing one-paragraph methods are split on newlines, then sentences.
 */
export function methodToSteps(method, methodSteps) {
  if (Array.isArray(methodSteps)) {
    const fromArray = methodSteps.map(cleanStep).filter(Boolean);
    if (fromArray.length) return fromArray;
  }
  const raw = String(method || "").replace(/\r\n/g, "\n").trim();
  if (!raw) return [];
  const lines = raw.split(/\n+/).map(cleanStep).filter(Boolean);
  if (lines.length > 1) return lines;
  return splitSentences(lines[0] || raw);
}

export function stepsToMethod(steps) {
  return methodToSteps(null, steps).join("\n");
}

/** Accept either `method_steps` or a method string from a write body. */
export function normalizeMethodInput(body) {
  if (!body || typeof body !== "object") return "";
  if (Array.isArray(body.method_steps)) return stepsToMethod(body.method_steps);
  return methodToSteps(body.method).join("\n");
}
