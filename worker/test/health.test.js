import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { APP_VERSION, SERVICE_NAME } from "../src/util.js";
import { DEMO_FIXTURES, demoAccounts } from "../src/auth.js";
import { testEnv } from "./helpers/memory-d1.js";

describe("health contract", () => {
  it("names the service and keeps fixture passwords out of source", () => {
    assert.equal(SERVICE_NAME, "week-on-plate");
    assert.equal(APP_VERSION, "0.1.2");
    assert.equal(DEMO_FIXTURES.creator.email, "creator@weekonplate.demo");
    assert.equal(DEMO_FIXTURES.creator.role, "creator");
    assert.equal(DEMO_FIXTURES.buyer.email, "buyer@weekonplate.demo");
    assert.equal(DEMO_FIXTURES.buyer.role, "buyer");
    assert.equal(demoAccounts({}).creator.password, "");
    assert.equal(demoAccounts({}).buyer.password, "");
    const accounts = demoAccounts(testEnv());
    assert.ok(accounts.creator.password.length >= 12);
    assert.ok(accounts.buyer.password.length >= 12);
  });
});
