import { describe, it, before } from "node:test";
import assert from "node:assert/strict";
import worker from "../src/index.js";
import { demoAccounts, resetLoginRateLimit } from "../src/auth.js";
import { testEnv } from "./helpers/memory-d1.js";

function req(path, { method = "GET", token, body } = {}) {
  const headers = {};
  if (token) headers.Authorization = `Bearer ${token}`;
  if (body !== undefined) headers["content-type"] = "application/json";
  return new Request(`https://week-on-plate.example.workers.dev${path}`, {
    method,
    headers,
    body: body === undefined ? undefined : JSON.stringify(body),
  });
}

async function jsonOf(res) {
  return { res, data: await res.json() };
}

describe("cupboard add and scan", { concurrency: false }, () => {
  const env = testEnv();
  let token;

  before(async () => {
    await resetLoginRateLimit(env);
    await worker.fetch(req("/api/health"), env);
    const login = await jsonOf(
      await worker.fetch(
        req("/api/auth/login", {
          method: "POST",
          body: { email: demoAccounts(env).buyer.email, password: demoAccounts(env).buyer.password },
        }),
        env,
      ),
    );
    token = login.data.token;
  });

  it("adds a manual cupboard item without replacing the rest", async () => {
    const first = await jsonOf(
      await worker.fetch(
        req("/api/cupboard/items", {
          method: "POST",
          token,
          body: { name: "Rice", quantity: 500, unit: "g" },
        }),
        env,
      ),
    );
    assert.equal(first.res.status, 200);
    const second = await jsonOf(
      await worker.fetch(
        req("/api/cupboard/items", {
          method: "POST",
          token,
          body: { items: [{ name: "Oats", quantity: 400, unit: "g" }] },
        }),
        env,
      ),
    );
    assert.equal(second.res.status, 200);
    const names = (second.data.items || []).map((i) => i.name).sort();
    assert.deepEqual(names, ["Oats", "Rice"]);
  });

  it("parses a typed shopping list without saving until add", async () => {
    const scan = await jsonOf(
      await worker.fetch(
        req("/api/cupboard/scan", {
          method: "POST",
          token,
          body: { text: "2 lemons\nHoney" },
        }),
        env,
      ),
    );
    assert.equal(scan.res.status, 200);
    assert.equal(scan.data.needs_confirm, true);
    assert.equal(scan.data.items.length, 2);
    assert.equal(scan.data.extractor, "heuristic");
    const after = await jsonOf(await worker.fetch(req("/api/cupboard", { token }), env));
    assert.equal((after.data.items || []).some((i) => /lemon/i.test(i.name)), false);
  });

  it("stores method_steps on create and splits a paragraph on read", async () => {
    const created = await jsonOf(
      await worker.fetch(
        req("/api/recipes", {
          method: "POST",
          token,
          body: {
            title: "Step stew",
            method_steps: ["Chop the onion.", "Simmer the beans."],
            serves: 2,
            published: true,
            ingredients: [{ name: "Beans", quantity: 1, unit: "each" }],
          },
        }),
        env,
      ),
    );
    assert.equal(created.res.status, 201);
    assert.deepEqual(created.data.recipe.method_steps, ["Chop the onion.", "Simmer the beans."]);

    const house = await jsonOf(await worker.fetch(req("/api/recipes/rcp_house_lemon_chicken", { token }), env));
    assert.equal(house.res.status, 200);
    assert.ok(house.data.recipe.method_steps.length >= 3);
    assert.match(house.data.recipe.method, /\n/);
  });
});
