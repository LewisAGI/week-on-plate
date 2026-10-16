import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { householdHeads, scaleFactor, scaleQuantity, DEFAULT_ADULTS } from "../src/domain/scale.js";

describe("scale", () => {
  it("defaults to two adults", () => {
    assert.equal(DEFAULT_ADULTS, 2);
    assert.equal(householdHeads(2, 0), 2);
  });

  it("counts under-18s as heads", () => {
    assert.equal(householdHeads(2, 1), 3);
  });

  it("scales a 4-serve recipe onto two adults", () => {
    assert.equal(scaleFactor(4, 2, 0), 0.5);
    assert.equal(scaleQuantity(400, 0.5), 200);
  });

  it("scales a 2-serve recipe onto two adults and one child", () => {
    assert.equal(scaleFactor(2, 2, 1), 1.5);
    assert.equal(scaleQuantity(160, 1.5), 240);
  });

  it("does not invert a missing serve count", () => {
    assert.equal(scaleFactor(0, 2, 0), 1);
    assert.equal(scaleQuantity(null, 2), null);
  });
});
