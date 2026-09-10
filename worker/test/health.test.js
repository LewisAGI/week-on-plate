import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { SERVICE_NAME } from "../src/util.js";
import { DEMO_ACCOUNTS } from "../src/auth.js";

describe("health contract", () => {
  it("names the service and publishes demo logins", () => {
    assert.equal(SERVICE_NAME, "week-on-plate");
    assert.equal(DEMO_ACCOUNTS.creator.email, "creator@weekonplate.demo");
    assert.equal(DEMO_ACCOUNTS.buyer.email, "buyer@weekonplate.demo");
    assert.ok(DEMO_ACCOUNTS.creator.password.length >= 12);
    assert.ok(DEMO_ACCOUNTS.buyer.password.length >= 12);
  });
});
