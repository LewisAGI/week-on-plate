import { describe, it } from "node:test";
import assert from "node:assert/strict";
import { extractFromCaption } from "../src/domain/extract.js";

describe("import extract", () => {
  it("pulls title, serves and ingredients from a pasted caption", () => {
    const draft = extractFromCaption(`High protein chicken bowl
Serves 2

Ingredients:
- 400g chicken breast
- 200g rice
- 1 tbsp olive oil

Method:
1. Cook the rice.
2. Fry the chicken.
https://www.instagram.com/reel/example`);
    assert.match(draft.title, /chicken bowl/i);
    assert.equal(draft.serves, 2);
    assert.equal(draft.ingredients.length, 3);
    assert.equal(draft.ingredients[0].quantity, 400);
    assert.match(draft.method, /Cook the rice/);
    assert.equal(draft.extractor, "heuristic");
  });

  it("does not invent an ingredient from a time line such as 30 mins", () => {
    const draft = extractFromCaption(`Lemon roast chicken
30 mins
Just some caption waffle and a link
https://www.instagram.com/reel/example`);
    assert.equal(draft.ingredients.length, 0);
    assert.equal(draft.minutes, 30);
    assert.match(draft.title, /lemon roast chicken/i);
  });
});
