import { apiError, json, newId, nowIso } from "./util.js";

const PBKDF2_ITERATIONS = 100000;
const SESSION_DAYS = 7;
const EMAIL_RE = /^[^\s@]+@[^\s@]+\.[^\s@]+$/;

export const DEMO_ACCOUNTS = {
  creator: {
    id: "usr_demo_creator",
    email: "creator@weekonplate.demo",
    password: "WeekOnPlate-Creator-26",
    display_name: "Sam Taylor",
  },
  buyer: {
    id: "usr_demo_buyer",
    email: "buyer@weekonplate.demo",
    password: "WeekOnPlate-Buyer-26",
    display_name: "Jordan Ellis",
  },
};

function bytesToB64(bytes) {
  let s = "";
  for (const b of bytes) s += String.fromCharCode(b);
  return btoa(s);
}

function b64ToBytes(b64) {
  const bin = atob(b64);
  const out = new Uint8Array(bin.length);
  for (let i = 0; i < bin.length; i++) out[i] = bin.charCodeAt(i);
  return out;
}

async function deriveHash(password, saltB64, iterations) {
  const key = await crypto.subtle.importKey(
    "raw",
    new TextEncoder().encode(password),
    "PBKDF2",
    false,
    ["deriveBits"],
  );
  const bits = await crypto.subtle.deriveBits(
    { name: "PBKDF2", hash: "SHA-256", salt: b64ToBytes(saltB64), iterations },
    key,
    256,
  );
  return bytesToB64(new Uint8Array(bits));
}

export async function hashPassword(password) {
  const saltBytes = new Uint8Array(16);
  crypto.getRandomValues(saltBytes);
  const salt = bytesToB64(saltBytes);
  const hash = await deriveHash(password, salt, PBKDF2_ITERATIONS);
  return { hash, salt, kdf: "pbkdf2-sha256", kdf_iterations: PBKDF2_ITERATIONS };
}

export async function verifyPassword(user, password) {
  if (!user?.password_hash || !user?.password_salt) return false;
  if (typeof password !== "string" || password === "") return false;
  const iterations = Number(user.kdf_iterations) || PBKDF2_ITERATIONS;
  const candidate = await deriveHash(password, user.password_salt, iterations);
  return candidate === user.password_hash;
}

function cookieValue(request) {
  const header = request.headers.get("Cookie") || "";
  const m = header.match(/(?:^|;\s*)wop_session=([^;]+)/);
  return m ? decodeURIComponent(m[1]) : "";
}

export function bearerToken(request) {
  const auth = request.headers.get("Authorization") || "";
  if (auth.toLowerCase().startsWith("bearer ")) return auth.slice(7).trim();
  return cookieValue(request);
}

export async function createSession(env, userId) {
  const token = newId("ses");
  const expires = new Date(Date.now() + SESSION_DAYS * 864e5).toISOString();
  await env.DB.prepare(
    "INSERT INTO sessions (token, user_id, expires_at, created_at) VALUES (?, ?, ?, ?)",
  )
    .bind(token, userId, expires, nowIso())
    .run();
  return { token, maxAgeS: SESSION_DAYS * 86400 };
}

export function sessionCookie(token, maxAgeS) {
  return `wop_session=${encodeURIComponent(token)}; Path=/; HttpOnly; Secure; SameSite=Lax; Max-Age=${maxAgeS}`;
}

export async function identify(request, env) {
  const token = bearerToken(request);
  if (!token) return null;
  const row = await env.DB.prepare(
    `SELECT u.* FROM sessions s JOIN users u ON u.id = s.user_id
     WHERE s.token = ? AND s.expires_at > ?`,
  )
    .bind(token, nowIso())
    .first();
  return row || null;
}

export function presentUser(user, household) {
  return {
    id: user.id,
    email: user.email,
    display_name: user.display_name,
    demo_fixture: Number(user.demo_fixture) === 1,
    household: household || { adults: 2, under18s: 0 },
  };
}

export async function loadHousehold(env, userId) {
  const row = await env.DB.prepare("SELECT adults, under18s FROM households WHERE user_id = ?")
    .bind(userId)
    .first();
  return row ? { adults: Number(row.adults), under18s: Number(row.under18s) } : { adults: 2, under18s: 0 };
}

export async function handleLogin(request, env) {
  const body = await request.json().catch(() => null);
  const email = String(body?.email || "")
    .trim()
    .toLowerCase();
  const password = typeof body?.password === "string" ? body.password : "";
  if (!EMAIL_RE.test(email) || !password) {
    return apiError(400, "bad_credentials_format", "An email address and a password are both needed.");
  }
  const user = await env.DB.prepare("SELECT * FROM users WHERE email = ?").bind(email).first();
  if (!user || !(await verifyPassword(user, password))) {
    return apiError(401, "bad_credentials", "That email address and password do not match an account.");
  }
  const session = await createSession(env, user.id);
  const household = await loadHousehold(env, user.id);
  const res = json({ ok: true, token: session.token, user: presentUser(user, household) });
  res.headers.set("Set-Cookie", sessionCookie(session.token, session.maxAgeS));
  return res;
}

export async function handleLogout(request, env) {
  const token = bearerToken(request);
  if (token) {
    await env.DB.prepare("DELETE FROM sessions WHERE token = ?").bind(token).run();
  }
  const res = json({ ok: true });
  res.headers.set("Set-Cookie", "wop_session=; Path=/; Max-Age=0");
  return res;
}

export async function handleMe(request, env) {
  const user = await identify(request, env);
  if (!user) return apiError(401, "not_authenticated", "You are not signed in.");
  const household = await loadHousehold(env, user.id);
  return json({ ok: true, user: presentUser(user, household) });
}
