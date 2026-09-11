import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { APP_VERSION, SERVICE_NAME } from "../src/util.js";
import { DEMO_ACCOUNTS } from "../src/auth.js";

describe("health contract", () => {
  it("names the service and publishes demo logins", () => {
    assert.equal(SERVICE_NAME, "week-on-plate");
    assert.equal(APP_VERSION, "0.1.2");
    assert.equal(DEMO_ACCOUNTS.creator.email, "creator@weekonplate.demo");
    assert.equal(DEMO_ACCOUNTS.creator.role, "creator");
    assert.equal(DEMO_ACCOUNTS.buyer.email, "buyer@weekonplate.demo");
    assert.equal(DEMO_ACCOUNTS.buyer.role, "buyer");
    assert.ok(DEMO_ACCOUNTS.creator.password.length >= 12);
    assert.ok(DEMO_ACCOUNTS.buyer.password.length >= 12);
  });
});
