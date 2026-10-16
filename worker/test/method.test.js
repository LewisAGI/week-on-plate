import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { methodToSteps, normalizeMethodInput, stepsToMethod } from "../src/domain/method.js";
import { parseShoppingListText } from "../src/domain/cupboard.js";
import { TEEN_TIP } from "../src/domain/scale.js";

describe("method steps", () => {
  it("keeps newline-delimited steps and strips numbering", () => {
    const steps = methodToSteps("1. Cook the rice.\n2. Fry the chicken.");
    assert.deepEqual(steps, ["Cook the rice.", "Fry the chicken."]);
  });

  it("splits an existing paragraph method into sentences", () => {
    const steps = methodToSteps(
      "Heat the oven to 200°C. Toss potatoes, chicken, lemon, garlic and oil on a tin. Roast 45–50 minutes until the chicken is cooked through. Rest five minutes, then serve.",
    );
    assert.equal(steps.length, 4);
    assert.match(steps[0], /Heat the oven/);
    assert.match(steps[3], /Rest five minutes/);
  });

  it("prefers a method_steps array on write", () => {
    assert.equal(normalizeMethodInput({ method_steps: ["Boil.", "Simmer."] }), "Boil.\nSimmer.");
    assert.equal(stepsToMethod(["  1. Season ", "Plate up"]), "Season\nPlate up");
  });
});

describe("shopping list parse", () => {
  it("reads qty lines and bare names", () => {
    const items = parseShoppingListText("Shopping list\n400g chicken breast\nMilk\n6 eggs");
    assert.equal(items.length, 3);
    assert.equal(items[0].name, "chicken breast");
    assert.equal(items[0].quantity, 400);
    assert.equal(items[0].unit, "g");
    assert.equal(items[1].name, "Milk");
    assert.equal(items[2].quantity, 6);
  });
});

describe("household copy", () => {
  it("softens the teen line", () => {
    assert.match(TEEN_TIP, /For teens: consider teenage eating habits/);
    assert.doesNotMatch(TEEN_TIP, /Consider teenage diets/);
  });
});
