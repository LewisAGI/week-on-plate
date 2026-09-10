export const SERVICE_NAME = "week-on-plate";
export const APP_VERSION = "0.1.0";

export function json(data, init = {}) {
  const headers = new Headers(init.headers || {});
  if (!headers.has("content-type")) headers.set("content-type", "application/json; charset=utf-8");
  if (!headers.has("cache-control")) headers.set("cache-control", "no-store");
  return new Response(JSON.stringify(data), { ...init, headers });
}

export function apiError(status, code, message, extra = {}) {
  return json({ ok: false, error: code, message, ...extra }, { status });
}

export function nowIso() {
  return new Date().toISOString();
}

export function newId(prefix) {
  const bytes = new Uint8Array(10);
  crypto.getRandomValues(bytes);
  const hex = [...bytes].map((b) => b.toString(16).padStart(2, "0")).join("");
  return `${prefix}_${hex}`;
}

export function corsHeaders(request) {
  const origin = request.headers.get("Origin") || "*";
  return {
    "access-control-allow-origin": origin,
    "access-control-allow-credentials": "true",
    "access-control-allow-headers": "Authorization, Content-Type",
    "access-control-allow-methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
    "access-control-expose-headers": "Authorization",
    vary: "Origin",
  };
}

export function withCors(response, request) {
  const headers = new Headers(response.headers);
  for (const [k, v] of Object.entries(corsHeaders(request))) headers.set(k, v);
  return new Response(response.body, { status: response.status, headers });
}

export async function readJson(request) {
  try {
    return { value: await request.json(), error: null };
  } catch {
    return { value: null, error: "That body was not JSON." };
  }
}

export function mondayOf(dateStr) {
  const d = dateStr && /^\d{4}-\d{2}-\d{2}$/.test(dateStr) ? new Date(`${dateStr}T00:00:00Z`) : new Date();
  const day = d.getUTCDay();
  const diff = day === 0 ? -6 : 1 - day;
  d.setUTCDate(d.getUTCDate() + diff);
  return d.toISOString().slice(0, 10);
}

export function addDays(dateStr, n) {
  const d = new Date(`${dateStr}T00:00:00Z`);
  d.setUTCDate(d.getUTCDate() + n);
  return d.toISOString().slice(0, 10);
}

export function weekDates(start) {
  const monday = mondayOf(start);
  return Array.from({ length: 7 }, (_, i) => addDays(monday, i));
}

export const SLOTS = ["breakfast", "lunch", "dinner", "snack"];

export function validSlot(v) {
  return SLOTS.includes(String(v || ""));
}

export function clampInt(v, min, max, fallback) {
  const n = Number.parseInt(v, 10);
  if (!Number.isFinite(n)) return fallback;
  return Math.min(max, Math.max(min, n));
}
