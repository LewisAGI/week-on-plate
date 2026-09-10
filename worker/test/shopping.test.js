import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { mergeIngredients, subtractCupboard, normalizeName } from "../src/domain/shopping.js";

describe("shopping merge", () => {
  it("merges the same ingredient across meals and converts kg", () => {
    const merged = mergeIngredients([
      { name: "Chicken breast", quantity: 400, unit: "g" },
      { name: "chicken breasts", quantity: 0.2, unit: "kg" },
      { name: "Olive oil", quantity: 2, unit: "tbsp" },
    ]);
    const chicken = merged.find((m) => m.normalized === "chicken breast");
    assert.equal(chicken.quantity, 600);
    assert.equal(chicken.unit, "g");
    const oil = merged.find((m) => m.normalized === "olive oil");
    assert.equal(oil.quantity, 30);
    assert.equal(oil.unit, "ml");
  });

  it("normalises plural names", () => {
    assert.equal(normalizeName("Tomatoes"), "tomato");
    assert.equal(normalizeName("berries"), "berry");
  });

  it("subtracts cupboard stock from the buy list", () => {
    const merged = mergeIngredients([
      { name: "Rice", quantity: 500, unit: "g" },
      { name: "Onions", quantity: 2, unit: "each" },
    ]);
    const { buy, already_have } = subtractCupboard(merged, [
      { name: "rice", quantity: 500, unit: "g", in_stock: 1 },
      { name: "Onions", quantity: 1, unit: "each", in_stock: 1 },
    ]);
    assert.equal(already_have.some((i) => i.normalized === "rice"), true);
    const onions = buy.find((i) => i.normalized === "onion");
    assert.equal(onions.still_needed, 1);
  });
});
