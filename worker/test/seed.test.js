import { describe, it, beforeEach } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";
import { DEMO_FIXTURES, demoAccounts, resetLoginRateLimit } from "../src/auth.js";
import { ensureSeeded, resetFixturePasswordSync } from "../src/seed.js";
import { testEnv } from "./helpers/memory-d1.js";

function loginRequest(email, password) {
  return new Request("https://week-on-plate.example.workers.dev/api/auth/login", {
    method: "POST",
    headers: { "content-type": "application/json" },
    body: JSON.stringify({ email, password }),
  });
}

describe("fixture seed", () => {
  beforeEach(() => {
    resetLoginRateLimit();
    resetFixturePasswordSync();
  });

  it("skips the seed when demo passwords are unset", async () => {
    const env = testEnv({
      DEMO_CREATOR_PASSWORD: "",
      DEMO_BUYER_PASSWORD: "",
    });
    const result = await ensureSeeded(env);
    assert.deepEqual(result, { seeded: false });
    const creator = await env.DB.prepare("SELECT id FROM users WHERE id = ?").bind(DEMO_FIXTURES.creator.id).first();
    const buyer = await env.DB.prepare("SELECT id FROM users WHERE id = ?").bind(DEMO_FIXTURES.buyer.id).first();
    assert.equal(creator, null);
    assert.equal(buyer, null);
  });

  it("syncFixturePassword rotates a fixture hash when the env password changes", async () => {
    const env = testEnv();
    const original = demoAccounts(env).creator.password;
    const first = await ensureSeeded(env);
    assert.equal(first.seeded, true);
    const before = await env.DB.prepare("SELECT password_hash FROM users WHERE id = ?")
      .bind(DEMO_FIXTURES.creator.id)
      .first();

    const rotated = ["rotated", "creator", "local", "only"].join("-");
    env.DEMO_CREATOR_PASSWORD = rotated;
    resetFixturePasswordSync();
    const second = await ensureSeeded(env);
    assert.equal(second.seeded, false);
    const after = await env.DB.prepare("SELECT password_hash FROM users WHERE id = ?")
      .bind(DEMO_FIXTURES.creator.id)
      .first();
    assert.notEqual(after.password_hash, before.password_hash);

    const ok = await worker.fetch(loginRequest(DEMO_FIXTURES.creator.email, rotated), env);
    assert.equal(ok.status, 200);
    const denied = await worker.fetch(loginRequest(DEMO_FIXTURES.creator.email, original), env);
    assert.equal(denied.status, 401);
  });
});
