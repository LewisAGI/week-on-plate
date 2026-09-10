import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { macrosForIngredients, scaleMacros, lookupNutrition } from "../src/domain/macros.js";

describe("macros", () => {
  it("looks up chicken and oats", () => {
    assert.ok(lookupNutrition("chicken breast"));
    assert.ok(lookupNutrition("Rolled oats"));
  });

  it("sums calories, protein, carbs, fat and sugar from ingredients", () => {
    const m = macrosForIngredients([
      { name: "Chicken breast", quantity: 200, unit: "g" },
      { name: "Olive oil", quantity: 1, unit: "tbsp" },
    ]);
    assert.ok(m.kcal > 200);
    assert.ok(m.protein > 50);
    assert.ok(m.fat > 10);
    assert.equal(m.ingredients_matched, 2);
    assert.ok("sugar" in m);
    assert.ok("carbs" in m);
  });

  it("scales a recipe's macros to the household", () => {
    const base = macrosForIngredients([{ name: "Salmon", quantity: 200, unit: "g" }]);
    const doubled = scaleMacros(base, 2);
    assert.equal(doubled.kcal, Math.round(base.kcal * 2 * 10) / 10);
  });
});
