import { describe, it, before } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";
import { demoAccounts, resetLoginRateLimit } from "../src/auth.js";
import { corsHeaders } from "../src/util.js";
import { testEnv } from "./helpers/memory-d1.js";

const ORIGIN_OK = "https://week-on-plate.example.workers.dev";
const ORIGIN_EVIL = "https://evil.example";

function req(path, { method = "GET", token, origin, body, headers = {} } = {}) {
  const h = { ...headers };
  if (origin) h.Origin = origin;
  if (token) h.Authorization = `Bearer ${token}`;
  if (body !== undefined) h["content-type"] = "application/json";
  return new Request(`https://week-on-plate.example.workers.dev${path}`, {
    method,
    headers: h,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

async function jsonOf(res) {
  return { res, data: await res.json(), headers: res.headers };
}

async function login(env, account, extra = {}) {
  const { res, data } = await jsonOf(
    await worker.fetch(
      req("/api/auth/login", {
        method: "POST",
        body: { email: account.email, password: account.password },
        ...extra,
      }),
      env,
    ),
  );
  assert.equal(res.status, 200, data.message || "login failed");
  return data.token;
}

describe("adversarial fixes", { concurrency: false }, () => {
  const env = testEnv();
  let creatorToken;
  let buyerToken;

  before(async () => {
    await resetLoginRateLimit(env);
    const health = await jsonOf(await worker.fetch(req("/api/health"), env));
    assert.equal(health.res.status, 200);
    const accounts = demoAccounts(env);
    creatorToken = await login(env, accounts.creator);
    buyerToken = await login(env, accounts.buyer);
  });

  it("CORS denies an evil origin and never pairs a reflected Origin with credentials", async () => {
    const preflight = corsHeaders(req("/api/health", { method: "OPTIONS", origin: ORIGIN_EVIL }));
    assert.notEqual(preflight["access-control-allow-origin"], ORIGIN_EVIL);
    assert.notEqual(preflight["access-control-allow-credentials"], "true");

    const res = await worker.fetch(req("/api/health", { method: "OPTIONS", origin: ORIGIN_EVIL }), env);
    assert.equal(res.status, 204);
    assert.notEqual(res.headers.get("access-control-allow-origin"), ORIGIN_EVIL);
    assert.notEqual(res.headers.get("access-control-allow-credentials"), "true");
  });

  it("CORS allows the Worker's own origin and localhost with credentials", async () => {
    const allowed = corsHeaders(req("/api/health", { origin: ORIGIN_OK }));
    assert.equal(allowed["access-control-allow-origin"], ORIGIN_OK);
    assert.equal(allowed["access-control-allow-credentials"], "true");

    const local = corsHeaders(
      new Request("http://127.0.0.1:8787/api/health", { headers: { Origin: "http://localhost:5173" } }),
    );
    assert.equal(local["access-control-allow-origin"], "http://localhost:5173");
    assert.equal(local["access-control-allow-credentials"], "true");
  });

  it("stamps health version 0.1.2 and a real build SHA", async () => {
    const { res, data } = await jsonOf(await worker.fetch(req("/api/health"), env));
    assert.equal(res.status, 200);
    assert.equal(data.version, "0.1.2");
    assert.equal(data.build, "testdeadbeef");
    assert.notEqual(data.build, "local");
  });

  it("returns role on login and /me", async () => {
    const me = await jsonOf(await worker.fetch(req("/api/auth/me", { token: buyerToken }), env));
    assert.equal(me.data.user.role, "buyer");
    const creator = await jsonOf(await worker.fetch(req("/api/auth/me", { token: creatorToken }), env));
    assert.equal(creator.data.user.role, "creator");
  });

  it("buyer is 403 on exclusive recipe create and pack create; ordinary recipe is allowed", async () => {
    const exclusive = await jsonOf(
      await worker.fetch(
        req("/api/recipes", {
          method: "POST",
          token: buyerToken,
          body: { title: "Buyer exclusive", exclusive: true, serves: 2, ingredients: [] },
        }),
        env,
      ),
    );
    assert.equal(exclusive.res.status, 403);
    assert.equal(exclusive.data.error, "creator_only");

    const ordinary = await jsonOf(
      await worker.fetch(
        req("/api/recipes", {
          method: "POST",
          token: buyerToken,
          body: { title: "Buyer stew", exclusive: false, serves: 2, ingredients: [{ name: "Beans", quantity: 1, unit: "each" }] },
        }),
        env,
      ),
    );
    assert.equal(ordinary.res.status, 201);
    assert.equal(ordinary.data.recipe.exclusive, false);

    const pack = await jsonOf(
      await worker.fetch(
        req("/api/packs", {
          method: "POST",
          token: buyerToken,
          body: { title: "Buyer pack", recipe_ids: [ordinary.data.recipe.id] },
        }),
        env,
      ),
    );
    assert.equal(pack.res.status, 403);
    assert.equal(pack.data.error, "creator_only");
  });

  it("creator can create a pack without flipping member exclusivity", async () => {
    const recipe = await jsonOf(
      await worker.fetch(
        req("/api/recipes", {
          method: "POST",
          token: creatorToken,
          body: {
            title: "Creator traybake",
            exclusive: false,
            published: true,
            serves: 2,
            ingredients: [{ name: "Salmon", quantity: 200, unit: "g" }],
          },
        }),
        env,
      ),
    );
    assert.equal(recipe.res.status, 201);
    assert.equal(recipe.data.recipe.exclusive, false);

    const pack = await jsonOf(
      await worker.fetch(
        req("/api/packs", {
          method: "POST",
          token: creatorToken,
          body: { title: "Weeknight extra", recipe_ids: [recipe.data.recipe.id], price_pence: 500 },
        }),
        env,
      ),
    );
    assert.equal(pack.res.status, 201);
    assert.ok(pack.data.pack_id);

    const again = await jsonOf(
      await worker.fetch(req(`/api/recipes/${recipe.data.recipe.id}`, { token: creatorToken }), env),
    );
    assert.equal(again.data.recipe.exclusive, false);
  });

  it("creator can mark a recipe exclusive", async () => {
    const recipe = await jsonOf(
      await worker.fetch(
        req("/api/recipes", {
          method: "POST",
          token: creatorToken,
          body: { title: "Pack-only pancakes", exclusive: true, serves: 2, ingredients: [] },
        }),
        env,
      ),
    );
    assert.equal(recipe.res.status, 201);
    assert.equal(recipe.data.recipe.exclusive, true);
  });

  it("week DELETE returns 404 when the slot is not the caller's", async () => {
    const slot = await jsonOf(
      await worker.fetch(
        req("/api/week/slots", {
          method: "PUT",
          token: creatorToken,
          body: { date: "2026-09-14", slot: "dinner", recipe_id: "rcp_house_oats" },
        }),
        env,
      ),
    );
    assert.equal(slot.res.status, 200);
    const foreign = await jsonOf(
      await worker.fetch(
        req(`/api/week/slots/${slot.data.slot_id}`, { method: "DELETE", token: buyerToken }),
        env,
      ),
    );
    assert.equal(foreign.res.status, 404);
    const missing = await jsonOf(
      await worker.fetch(req("/api/week/slots/slt_does_not_exist", { method: "DELETE", token: buyerToken }), env),
    );
    assert.equal(missing.res.status, 404);
    const own = await jsonOf(
      await worker.fetch(
        req(`/api/week/slots/${slot.data.slot_id}`, { method: "DELETE", token: creatorToken }),
        env,
      ),
    );
    assert.equal(own.res.status, 200);
  });

  it("household rejects negatives, non-integers and out-of-range with 400", async () => {
    for (const body of [
      { adults: -1, under18s: 0 },
      { adults: 2.5, under18s: 0 },
      { adults: "two", under18s: 1 },
      { adults: 99, under18s: 0 },
      { adults: 2, under18s: -3 },
    ]) {
      const { res, data } = await jsonOf(
        await worker.fetch(req("/api/household", { method: "PUT", token: buyerToken, body }), env),
      );
      assert.equal(res.status, 400, JSON.stringify({ body, data }));
      assert.equal(data.error, "bad_household");
    }
    const ok = await jsonOf(
      await worker.fetch(
        req("/api/household", { method: "PUT", token: buyerToken, body: { adults: 2, under18s: 1 } }),
        env,
      ),
    );
    assert.equal(ok.res.status, 200);
    assert.deepEqual(ok.data.household, { adults: 2, under18s: 1 });
  });

  it("rejects XSS-shaped titles on recipe and pack writes", async () => {
    const recipe = await jsonOf(
      await worker.fetch(
        req("/api/recipes", {
          method: "POST",
          token: creatorToken,
          body: { title: "<script>alert(1)</script>", serves: 2, ingredients: [] },
        }),
        env,
      ),
    );
    assert.equal(recipe.res.status, 400);
    assert.equal(recipe.data.error, "bad_title");

    const pack = await jsonOf(
      await worker.fetch(
        req("/api/packs", {
          method: "POST",
          token: creatorToken,
          body: { title: "<img src=x onerror=alert(1)>", recipe_ids: ["rcp_house_oats"] },
        }),
        env,
      ),
    );
    assert.equal(pack.res.status, 400);
    assert.equal(pack.data.error, "bad_title");
  });

  it("does not leak err.message on 500 responses", async () => {
    const broken = {
      prepare() {
        throw new Error("secret-leak-xyz");
      },
    };
    const { res, data } = await jsonOf(await worker.fetch(req("/api/health"), { DB: broken, BUILD_SHA: "x" }));
    assert.equal(res.status, 500);
    assert.equal(data.message, "Something went wrong on the server.");
    assert.equal(data.detail, undefined);
    assert.ok(!JSON.stringify(data).includes("secret-leak-xyz"));
  });

  async function loginAttempt(target, { ip, email, password = "wrong-password-xx" } = {}) {
    return jsonOf(
      await worker.fetch(
        req("/api/auth/login", {
          method: "POST",
          headers: ip ? { "CF-Connecting-IP": ip } : {},
          body: { email, password },
        }),
        target,
      ),
    );
  }

  it("rate-limits login attempts with 429", async () => {
    await resetLoginRateLimit(env);
    const tight = testEnv({ LOGIN_ATTEMPT_LIMIT: 3, DB: env.DB });
    let last;
    for (let i = 0; i < 4; i += 1) {
      last = await loginAttempt(tight, { ip: "203.0.113.9", email: "nobody@weekonplate.demo" });
    }
    assert.equal(last.res.status, 429);
    assert.equal(last.data.error, "rate_limited");
    const stored = await env.DB.prepare(
      "SELECT attempt_count FROM login_attempts WHERE bucket_key = ?",
    )
      .bind("email:nobody@weekonplate.demo")
      .first();
    assert.equal(Number(stored.attempt_count), 4);
    await resetLoginRateLimit(env);
  });

  it("rate-limits the same email across IP addresses", async () => {
    const tight = testEnv({ LOGIN_ATTEMPT_LIMIT: 2 });
    const email = "shared@weekonplate.demo";
    const first = await loginAttempt(tight, { ip: "203.0.113.10", email });
    const second = await loginAttempt(tight, { ip: "203.0.113.11", email });
    const third = await loginAttempt(tight, { ip: "203.0.113.12", email });
    assert.equal(first.res.status, 401);
    assert.equal(second.res.status, 401);
    assert.equal(third.res.status, 429);
    assert.equal(third.data.error, "rate_limited");
  });

  it("rate-limits one IP address across email addresses", async () => {
    const tight = testEnv({ LOGIN_ATTEMPT_LIMIT: 2 });
    const ip = "203.0.113.20";
    const first = await loginAttempt(tight, { ip, email: "one@weekonplate.demo" });
    const second = await loginAttempt(tight, { ip, email: "two@weekonplate.demo" });
    const third = await loginAttempt(tight, { ip, email: "three@weekonplate.demo" });
    assert.equal(first.res.status, 401);
    assert.equal(second.res.status, 401);
    assert.equal(third.res.status, 429);
    assert.equal(third.data.error, "rate_limited");
  });

  it("opens a new D1 window after the stored reset time", async () => {
    const tight = testEnv({ LOGIN_ATTEMPT_LIMIT: 1 });
    const email = "window@weekonplate.demo";
    const ip = "203.0.113.30";
    const first = await loginAttempt(tight, { ip, email });
    const blocked = await loginAttempt(tight, { ip, email });
    assert.equal(first.res.status, 401);
    assert.equal(blocked.res.status, 429);
    await tight.DB.prepare("UPDATE login_attempts SET reset_at = 0").run();
    const again = await loginAttempt(tight, { ip, email });
    assert.equal(again.res.status, 401);
    const row = await tight.DB.prepare(
      "SELECT attempt_count FROM login_attempts WHERE bucket_key = ?",
    )
      .bind(`email:${email}`)
      .first();
    assert.equal(Number(row.attempt_count), 1);
  });

  it("does not share login rate limits across databases", async () => {
    const firstEnv = testEnv({ LOGIN_ATTEMPT_LIMIT: 1 });
    const secondEnv = testEnv({ LOGIN_ATTEMPT_LIMIT: 1 });
    const email = "isolated@weekonplate.demo";
    const opened = await loginAttempt(firstEnv, { ip: "203.0.113.40", email });
    const blocked = await loginAttempt(firstEnv, { ip: "203.0.113.40", email });
    const other = await loginAttempt(secondEnv, { ip: "203.0.113.40", email });
    assert.equal(opened.res.status, 401);
    assert.equal(blocked.res.status, 429);
    assert.equal(other.res.status, 401);
    const leaked = await secondEnv.DB.prepare("SELECT COUNT(*) AS n FROM login_attempts").first();
    const local = await firstEnv.DB.prepare("SELECT COUNT(*) AS n FROM login_attempts").first();
    assert.equal(Number(leaked.n), 2);
    assert.equal(Number(local.n), 2);
  });
});
