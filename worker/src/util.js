export const SERVICE_NAME = "week-on-plate";
export const APP_VERSION = "0.1.2";

export const ALLOWED_WEB_HOSTS = new Set([
  "week-on-plate.lewismgodfrey.workers.dev",
  "localhost",
  "127.0.0.1",
  "10.0.2.2",
  "[::1]",
]);

const UNSAFE_TITLE_RE = /<\s*\/?\s*[a-z]|javascript\s*:/i;

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

export function isAllowlistedOrigin(origin, requestUrl) {
  if (!origin || origin === "null") return false;
  let parsed;
  try {
    parsed = new URL(origin);
  } catch {
    return false;
  }
  if (parsed.protocol !== "http:" && parsed.protocol !== "https:") return false;
  if (ALLOWED_WEB_HOSTS.has(parsed.hostname)) return true;
  if (requestUrl) {
    try {
      if (parsed.origin === new URL(requestUrl).origin) return true;
    } catch {
      /* ignore */
    }
  }
  return false;
}

export function corsHeaders(request) {
  const origin = request.headers.get("Origin");
  const headers = {
    "access-control-allow-headers": "Authorization, Content-Type",
    "access-control-allow-methods": "GET, POST, PUT, PATCH, DELETE, OPTIONS",
    "access-control-expose-headers": "Authorization",
    vary: "Origin",
  };
  if (!origin) return headers;
  if (origin === "null") {
    // Mobile / sandboxed clients: Bearer only — never pair null with credentials.
    headers["access-control-allow-origin"] = "null";
    return headers;
  }
  if (isAllowlistedOrigin(origin, request.url)) {
    headers["access-control-allow-origin"] = origin;
    headers["access-control-allow-credentials"] = "true";
  }
  return headers;
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

export function parseBoundedInt(value, { min, max, name }) {
  if (value === undefined || value === null || value === "") {
    return { error: `${name} is required.` };
  }
  if (typeof value === "boolean") {
    return { error: `${name} must be a whole number.` };
  }
  let n;
  if (typeof value === "number") {
    if (!Number.isInteger(value)) return { error: `${name} must be a whole number.` };
    n = value;
  } else if (typeof value === "string") {
    const trimmed = value.trim();
    if (!/^-?\d+$/.test(trimmed)) return { error: `${name} must be a whole number.` };
    n = Number(trimmed);
  } else {
    return { error: `${name} must be a whole number.` };
  }
  if (!Number.isInteger(n) || n < min || n > max) {
    return { error: `${name} must be between ${min} and ${max}.` };
  }
  return { value: n };
}

export function isUnsafeTitle(title) {
  return UNSAFE_TITLE_RE.test(String(title || ""));
}

export function rejectUnsafeTitle(title) {
  if (isUnsafeTitle(title)) {
    return apiError(400, "bad_title", "That title contains markup we cannot store.");
  }
  return null;
}

export function resolveVersion(env) {
  return (env && env.APP_VERSION && String(env.APP_VERSION)) || APP_VERSION;
}

export function resolveBuild(env) {
  const sha = env && env.BUILD_SHA != null ? String(env.BUILD_SHA).trim() : "";
  return sha || "local";
}
