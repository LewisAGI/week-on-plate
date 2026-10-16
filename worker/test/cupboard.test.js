import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { suggestAdjustments, applyAdjustment, COLD_START_STAPLES } from "../src/domain/cupboard.js";

describe("cupboard", () => {
  it("ships a cold-start staple list", () => {
    assert.ok(COLD_START_STAPLES.length >= 8);
    assert.ok(COLD_START_STAPLES.some((s) => /olive oil/i.test(s.name)));
  });

  it("suggests decrement or untick after a meal is cooked", () => {
    const suggestions = suggestAdjustments(
      [
        { name: "Rice", quantity: 160, unit: "g" },
        { name: "Olive oil", quantity: 15, unit: "ml" },
      ],
      [
        { id: "c1", name: "Rice", quantity: 500, unit: "g", in_stock: 1 },
        { id: "c2", name: "Olive oil", quantity: 15, unit: "ml", in_stock: 1 },
      ],
    );
    const rice = suggestions.find((s) => s.id === "c1");
    assert.equal(rice.action, "decrement");
    assert.equal(rice.remaining, 340);
    const oil = suggestions.find((s) => s.id === "c2");
    assert.equal(oil.action, "untick");
    const after = applyAdjustment({ id: "c1", quantity: 500, in_stock: 1 }, rice);
    assert.equal(after.quantity, 340);
  });
});
