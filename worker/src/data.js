import { creatorOnlyError, isCreator, loadHousehold } from "./auth.js";
import { COLD_START_STAPLES, suggestAdjustments } from "./domain/cupboard.js";
import { extractFromCaption, draftFromModelJson } from "./domain/extract.js";
import { macrosForIngredients, scaleMacros } from "./domain/macros.js";
import { scaleFactor, scaleQuantity } from "./domain/scale.js";
import { mergeIngredients, subtractCupboard } from "./domain/shopping.js";
import { apiError, json, newId, nowIso, clampInt, parseBoundedInt, rejectUnsafeTitle, validSlot, weekDates } from "./util.js";

export async function purchasedPackIds(env, userId) {
  const { results } = await env.DB.prepare("SELECT pack_id FROM purchases WHERE user_id = ?")
    .bind(userId)
    .all();
  return new Set((results || []).map((r) => r.pack_id));
}

export async function exclusiveRecipeAccess(env, userId) {
  const { results } = await env.DB.prepare(
    `SELECT pr.recipe_id FROM pack_recipes pr
     JOIN purchases p ON p.pack_id = pr.pack_id
     WHERE p.user_id = ?`,
  )
    .bind(userId)
    .all();
  return new Set((results || []).map((r) => r.recipe_id));
}

export async function canSeeRecipe(env, user, recipe) {
  if (!recipe) return false;
  if (recipe.author_id === user.id) return true;
  if (Number(recipe.house_recipe) === 1) return true;
  if (Number(recipe.exclusive) === 1) {
    const access = await exclusiveRecipeAccess(env, user.id);
    return access.has(recipe.id);
  }
  return Number(recipe.published) === 1;
}

export async function loadIngredients(env, recipeId) {
  const { results } = await env.DB.prepare(
    "SELECT * FROM ingredients WHERE recipe_id = ? ORDER BY sort_order ASC",
  )
    .bind(recipeId)
    .all();
  return results || [];
}

export function presentIngredient(row) {
  return {
    id: row.id,
    name: row.name,
    quantity: row.quantity == null ? null : Number(row.quantity),
    unit: row.unit || "each",
    notes: row.notes || null,
  };
}

export async function presentRecipe(env, recipe, user, extra = {}) {
  const ingredients = (await loadIngredients(env, recipe.id)).map(presentIngredient);
  const household = extra.household || (await loadHousehold(env, user.id));
  const factor = scaleFactor(recipe.serves, household.adults, household.under18s);
  const scaled = ingredients.map((ing) => ({
    ...ing,
    quantity: scaleQuantity(ing.quantity, factor),
  }));
  const macros = macrosForIngredients(ingredients);
  const saved = extra.savedIds ? extra.savedIds.has(recipe.id) : false;
  return {
    id: recipe.id,
    author_id: recipe.author_id,
    title: recipe.title,
    summary: recipe.summary,
    method: recipe.method,
    serves: Number(recipe.serves),
    minutes: recipe.minutes == null ? null : Number(recipe.minutes),
    published: Number(recipe.published) === 1,
    house_recipe: Number(recipe.house_recipe) === 1,
    exclusive: Number(recipe.exclusive) === 1,
    ingredients,
    scaled_ingredients: scaled,
    scale_factor: factor,
    macros,
    scaled_macros: scaleMacros(macros, factor),
    saved,
    mine: recipe.author_id === user.id,
  };
}

export async function savedIds(env, userId) {
  const { results } = await env.DB.prepare("SELECT recipe_id FROM saved_recipes WHERE user_id = ?")
    .bind(userId)
    .all();
  return new Set((results || []).map((r) => r.recipe_id));
}

export async function replaceIngredients(env, recipeId, ingredients) {
  await env.DB.prepare("DELETE FROM ingredients WHERE recipe_id = ?").bind(recipeId).run();
  let i = 0;
  for (const ing of ingredients || []) {
    const name = String(ing.name || "").trim();
    if (!name) continue;
    i += 1;
    await env.DB.prepare(
      `INSERT INTO ingredients (id, recipe_id, name, quantity, unit, notes, sort_order)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
    )
      .bind(
        newId("ing"),
        recipeId,
        name,
        ing.quantity == null || ing.quantity === "" ? null : Number(ing.quantity),
        String(ing.unit || "each"),
        ing.notes || null,
        i,
      )
      .run();
  }
}

export async function handleHouseholdGet(env, user) {
  return json({ ok: true, household: await loadHousehold(env, user.id) });
}

export async function handleHouseholdPut(request, env, user) {
  const body = await request.json().catch(() => null);
  if (!body || typeof body !== "object") {
    return apiError(400, "bad_household", "Adults and under-18s must be whole numbers in range.");
  }
  const adults = parseBoundedInt(body.adults, { min: 1, max: 12, name: "Adults" });
  if (adults.error) return apiError(400, "bad_household", adults.error);
  const under18s = parseBoundedInt(body.under18s, { min: 0, max: 12, name: "Under-18s" });
  if (under18s.error) return apiError(400, "bad_household", under18s.error);
  await env.DB.prepare(
    `INSERT INTO households (user_id, adults, under18s, updated_at) VALUES (?, ?, ?, ?)
     ON CONFLICT(user_id) DO UPDATE SET adults = excluded.adults, under18s = excluded.under18s, updated_at = excluded.updated_at`,
  )
    .bind(user.id, adults.value, under18s.value, nowIso())
    .run();
  return json({ ok: true, household: { adults: adults.value, under18s: under18s.value } });
}

export async function handleRecipeList(url, env, user) {
  const scope = url.searchParams.get("scope") || "browse";
  const access = await exclusiveRecipeAccess(env, user.id);
  const saved = await savedIds(env, user.id);
  const household = await loadHousehold(env, user.id);
  const { results } = await env.DB.prepare("SELECT * FROM recipes ORDER BY house_recipe DESC, title ASC").all();
  const visible = [];
  for (const recipe of results || []) {
    const mine = recipe.author_id === user.id;
    const house = Number(recipe.house_recipe) === 1;
    const exclusive = Number(recipe.exclusive) === 1;
    const purchased = access.has(recipe.id);
    const isSaved = saved.has(recipe.id);
    const published = Number(recipe.published) === 1;
    let ok = false;
    if (scope === "mine") ok = mine;
    else if (scope === "saved") ok = isSaved && (mine || house || published || purchased);
    else if (scope === "house") ok = house;
    else ok = mine || house || purchased || (published && !exclusive);
    if (ok) visible.push(recipe);
  }
  const items = [];
  for (const recipe of visible) {
    items.push(await presentRecipe(env, recipe, user, { household, savedIds: saved }));
  }
  return json({ ok: true, recipes: items });
}

export async function handleRecipeGet(env, user, id) {
  const recipe = await env.DB.prepare("SELECT * FROM recipes WHERE id = ?").bind(id).first();
  if (!recipe || !(await canSeeRecipe(env, user, recipe))) {
    return apiError(404, "not_found", "That recipe is not on your plate.");
  }
  const saved = await savedIds(env, user.id);
  return json({ ok: true, recipe: await presentRecipe(env, recipe, user, { savedIds: saved }) });
}

function recipeFields(body) {
  return {
    title: String(body?.title || "").trim(),
    summary: String(body?.summary || "").trim(),
    method: String(body?.method || "").trim(),
    serves: clampInt(body?.serves, 1, 20, 2),
    minutes: body?.minutes == null || body?.minutes === "" ? null : clampInt(body.minutes, 1, 600, null),
    published: body?.published ? 1 : 0,
    exclusive: body?.exclusive ? 1 : 0,
    ingredients: Array.isArray(body?.ingredients) ? body.ingredients : [],
    source_text: body?.source_text ? String(body.source_text) : null,
  };
}

export async function handleRecipeCreate(request, env, user) {
  const body = await request.json().catch(() => null);
  if (body?.exclusive && !isCreator(user)) return creatorOnlyError();
  const f = recipeFields(body);
  if (!isCreator(user)) f.exclusive = 0;
  if (f.title.length < 2) return apiError(400, "bad_title", "Give the recipe a name.");
  const unsafe = rejectUnsafeTitle(f.title);
  if (unsafe) return unsafe;
  const id = newId("rcp");
  const ts = nowIso();
  await env.DB.prepare(
    `INSERT INTO recipes
      (id, author_id, title, summary, method, serves, minutes, published, house_recipe, exclusive, source_text, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, ?, 0, ?, ?, ?, ?)`,
  )
    .bind(id, user.id, f.title, f.summary, f.method, f.serves, f.minutes, f.published, f.exclusive, f.source_text, ts, ts)
    .run();
  await replaceIngredients(env, id, f.ingredients);
  const recipe = await env.DB.prepare("SELECT * FROM recipes WHERE id = ?").bind(id).first();
  return json({ ok: true, recipe: await presentRecipe(env, recipe, user) }, { status: 201 });
}

export async function handleRecipeUpdate(request, env, user, id) {
  const recipe = await env.DB.prepare("SELECT * FROM recipes WHERE id = ?").bind(id).first();
  if (!recipe || recipe.author_id !== user.id) {
    return apiError(403, "not_yours", "Only the author can edit this recipe.");
  }
  const body = await request.json().catch(() => null);
  if (body?.exclusive && !isCreator(user)) return creatorOnlyError();
  const f = recipeFields({ ...recipe, ...body, ingredients: body?.ingredients ?? undefined });
  if (!isCreator(user)) f.exclusive = Number(recipe.exclusive) === 1 ? 1 : 0;
  if (f.title.length < 2) return apiError(400, "bad_title", "Give the recipe a name.");
  const unsafe = rejectUnsafeTitle(f.title);
  if (unsafe) return unsafe;
  await env.DB.prepare(
    `UPDATE recipes SET title = ?, summary = ?, method = ?, serves = ?, minutes = ?, published = ?, exclusive = ?, updated_at = ?
     WHERE id = ?`,
  )
    .bind(f.title, f.summary, f.method, f.serves, f.minutes, f.published, f.exclusive, nowIso(), id)
    .run();
  if (Array.isArray(body?.ingredients)) await replaceIngredients(env, id, body.ingredients);
  const updated = await env.DB.prepare("SELECT * FROM recipes WHERE id = ?").bind(id).first();
  return json({ ok: true, recipe: await presentRecipe(env, updated, user) });
}

export async function handleRecipePublish(env, user, id) {
  const recipe = await env.DB.prepare("SELECT * FROM recipes WHERE id = ?").bind(id).first();
  if (!recipe || recipe.author_id !== user.id) {
    return apiError(403, "not_yours", "Only the author can publish this recipe.");
  }
  await env.DB.prepare("UPDATE recipes SET published = 1, updated_at = ? WHERE id = ?")
    .bind(nowIso(), id)
    .run();
  const updated = await env.DB.prepare("SELECT * FROM recipes WHERE id = ?").bind(id).first();
  return json({ ok: true, recipe: await presentRecipe(env, updated, user) });
}

export async function handleRecipeSave(env, user, id, on) {
  const recipe = await env.DB.prepare("SELECT * FROM recipes WHERE id = ?").bind(id).first();
  if (!recipe || !(await canSeeRecipe(env, user, recipe))) {
    return apiError(404, "not_found", "That recipe is not on your plate.");
  }
  if (on) {
    await env.DB.prepare(
      "INSERT OR IGNORE INTO saved_recipes (user_id, recipe_id, created_at) VALUES (?, ?, ?)",
    )
      .bind(user.id, id, nowIso())
      .run();
  } else {
    await env.DB.prepare("DELETE FROM saved_recipes WHERE user_id = ? AND recipe_id = ?")
      .bind(user.id, id)
      .run();
  }
  return json({ ok: true, saved: on });
}

export async function handleWeekGet(url, env, user) {
  const dates = weekDates(url.searchParams.get("start"));
  const household = await loadHousehold(env, user.id);
  const { results } = await env.DB.prepare(
    `SELECT * FROM week_slots WHERE user_id = ? AND plan_date >= ? AND plan_date <= ? ORDER BY plan_date, slot`,
  )
    .bind(user.id, dates[0], dates[6])
    .all();
  const slots = [];
  const byDay = {};
  for (const d of dates) byDay[d] = { date: d, slots: [], macros: null };
  for (const row of results || []) {
    const recipe = await env.DB.prepare("SELECT * FROM recipes WHERE id = ?").bind(row.recipe_id).first();
    if (!recipe) continue;
    const presented = await presentRecipe(env, recipe, user, { household });
    const factor =
      row.servings != null
        ? Number(row.servings) / Number(recipe.serves)
        : presented.scale_factor;
    const item = {
      id: row.id,
      date: row.plan_date,
      slot: row.slot,
      cooked: Number(row.cooked) === 1,
      servings: row.servings == null ? null : Number(row.servings),
      recipe: presented,
      macros: scaleMacros(presented.macros, factor),
    };
    slots.push(item);
    byDay[row.plan_date].slots.push(item);
  }
  for (const d of dates) {
    let macros = { kcal: 0, protein: 0, carbs: 0, fat: 0, sugar: 0, estimated: true };
    for (const s of byDay[d].slots) {
      macros = {
        kcal: Math.round((macros.kcal + s.macros.kcal) * 10) / 10,
        protein: Math.round((macros.protein + s.macros.protein) * 10) / 10,
        carbs: Math.round((macros.carbs + s.macros.carbs) * 10) / 10,
        fat: Math.round((macros.fat + s.macros.fat) * 10) / 10,
        sugar: Math.round((macros.sugar + s.macros.sugar) * 10) / 10,
        estimated: true,
      };
    }
    byDay[d].macros = macros;
  }
  return json({ ok: true, start: dates[0], days: dates.map((d) => byDay[d]), household });
}

export async function handleWeekPut(request, env, user) {
  const body = await request.json().catch(() => null);
  const date = String(body?.date || "");
  const slot = String(body?.slot || "");
  const recipeId = String(body?.recipe_id || "");
  if (!/^\d{4}-\d{2}-\d{2}$/.test(date) || !validSlot(slot) || !recipeId) {
    return apiError(400, "bad_slot", "Need a date, a slot (breakfast/lunch/dinner/snack) and a recipe.");
  }
  const recipe = await env.DB.prepare("SELECT * FROM recipes WHERE id = ?").bind(recipeId).first();
  if (!recipe || !(await canSeeRecipe(env, user, recipe))) {
    return apiError(404, "not_found", "That recipe is not on your plate.");
  }
  const existing = await env.DB.prepare(
    "SELECT id FROM week_slots WHERE user_id = ? AND plan_date = ? AND slot = ?",
  )
    .bind(user.id, date, slot)
    .first();
  const id = existing?.id || newId("slt");
  if (existing) {
    await env.DB.prepare("UPDATE week_slots SET recipe_id = ?, cooked = 0 WHERE id = ?")
      .bind(recipeId, id)
      .run();
  } else {
    await env.DB.prepare(
      `INSERT INTO week_slots (id, user_id, plan_date, slot, recipe_id, servings, cooked, created_at)
       VALUES (?, ?, ?, ?, ?, NULL, 0, ?)`,
    )
      .bind(id, user.id, date, slot, recipeId, nowIso())
      .run();
  }
  return json({ ok: true, slot_id: id });
}

export async function handleWeekDelete(env, user, id) {
  const existing = await env.DB.prepare("SELECT id FROM week_slots WHERE id = ? AND user_id = ?")
    .bind(id, user.id)
    .first();
  if (!existing) return apiError(404, "not_found", "That meal is not on your week.");
  await env.DB.prepare("DELETE FROM week_slots WHERE id = ? AND user_id = ?").bind(id, user.id).run();
  return json({ ok: true });
}

export async function handleWeekCooked(env, user, id) {
  const row = await env.DB.prepare("SELECT * FROM week_slots WHERE id = ? AND user_id = ?")
    .bind(id, user.id)
    .first();
  if (!row) return apiError(404, "not_found", "That meal is not on your week.");
  await env.DB.prepare("UPDATE week_slots SET cooked = 1 WHERE id = ?").bind(id).run();
  const household = await loadHousehold(env, user.id);
  const recipe = await env.DB.prepare("SELECT * FROM recipes WHERE id = ?").bind(row.recipe_id).first();
  const presented = recipe ? await presentRecipe(env, recipe, user, { household }) : null;
  const { results } = await env.DB.prepare("SELECT * FROM cupboard_items WHERE user_id = ?")
    .bind(user.id)
    .all();
  const suggestions = presented
    ? suggestAdjustments(presented.scaled_ingredients, results || [])
    : [];
  return json({
    ok: true,
    cooked: true,
    prompt: "Shall we take these off the cupboard?",
    suggestions,
  });
}

export async function handleShopping(url, env, user) {
  const dates = weekDates(url.searchParams.get("start"));
  const household = await loadHousehold(env, user.id);
  const { results } = await env.DB.prepare(
    `SELECT * FROM week_slots WHERE user_id = ? AND plan_date >= ? AND plan_date <= ?`,
  )
    .bind(user.id, dates[0], dates[6])
    .all();
  const scaled = [];
  for (const row of results || []) {
    const recipe = await env.DB.prepare("SELECT * FROM recipes WHERE id = ?").bind(row.recipe_id).first();
    if (!recipe) continue;
    const presented = await presentRecipe(env, recipe, user, { household });
    scaled.push(...presented.scaled_ingredients);
  }
  const merged = mergeIngredients(scaled);
  const { results: cupboard } = await env.DB.prepare("SELECT * FROM cupboard_items WHERE user_id = ?")
    .bind(user.id)
    .all();
  const split = subtractCupboard(merged, cupboard || []);
  return json({ ok: true, start: dates[0], merged, ...split });
}

export async function handleCupboardGet(env, user) {
  const { results } = await env.DB.prepare(
    "SELECT * FROM cupboard_items WHERE user_id = ? ORDER BY name ASC",
  )
    .bind(user.id)
    .all();
  return json({
    ok: true,
    items: results || [],
    empty: !results || results.length === 0,
    staples: COLD_START_STAPLES,
  });
}

export async function handleCupboardPut(request, env, user) {
  const body = await request.json().catch(() => null);
  const items = Array.isArray(body?.items) ? body.items : [];
  await env.DB.prepare("DELETE FROM cupboard_items WHERE user_id = ?").bind(user.id).run();
  const ts = nowIso();
  for (const item of items) {
    const name = String(item.name || "").trim();
    if (!name) continue;
    await env.DB.prepare(
      `INSERT INTO cupboard_items (id, user_id, name, quantity, unit, in_stock, updated_at)
       VALUES (?, ?, ?, ?, ?, ?, ?)`,
    )
      .bind(
        newId("cup"),
        user.id,
        name,
        item.quantity == null || item.quantity === "" ? null : Number(item.quantity),
        String(item.unit || "each"),
        item.in_stock === 0 ? 0 : 1,
        ts,
      )
      .run();
  }
  return handleCupboardGet(env, user);
}

export async function handleCupboardPatch(request, env, user, id) {
  const body = await request.json().catch(() => null);
  const row = await env.DB.prepare("SELECT * FROM cupboard_items WHERE id = ? AND user_id = ?")
    .bind(id, user.id)
    .first();
  if (!row) return apiError(404, "not_found", "That cupboard item is not there.");
  const inStock = body?.in_stock == null ? row.in_stock : body.in_stock ? 1 : 0;
  const quantity = body?.quantity === undefined ? row.quantity : body.quantity;
  await env.DB.prepare(
    "UPDATE cupboard_items SET in_stock = ?, quantity = ?, updated_at = ? WHERE id = ?",
  )
    .bind(inStock, quantity, nowIso(), id)
    .run();
  return json({ ok: true });
}

export async function handleCupboardAdjust(request, env, user) {
  const body = await request.json().catch(() => null);
  const suggestions = Array.isArray(body?.suggestions) ? body.suggestions : [];
  for (const s of suggestions) {
    if (!s.id || s.action === "none") continue;
    if (s.action === "untick") {
      await env.DB.prepare(
        "UPDATE cupboard_items SET in_stock = 0, quantity = 0, updated_at = ? WHERE id = ? AND user_id = ?",
      )
        .bind(nowIso(), s.id, user.id)
        .run();
    } else if (s.action === "decrement") {
      await env.DB.prepare(
        "UPDATE cupboard_items SET quantity = ?, in_stock = 1, updated_at = ? WHERE id = ? AND user_id = ?",
      )
        .bind(s.remaining, nowIso(), s.id, user.id)
        .run();
    }
  }
  return handleCupboardGet(env, user);
}

export async function handleColdStart(request, env, user) {
  const body = await request.json().catch(() => null);
  const names = new Set((body?.names || []).map((n) => String(n).toLowerCase()));
  const chosen = COLD_START_STAPLES.filter((s) => names.has(s.name.toLowerCase()));
  const ts = nowIso();
  for (const item of chosen) {
    await env.DB.prepare(
      `INSERT INTO cupboard_items (id, user_id, name, quantity, unit, in_stock, updated_at)
       VALUES (?, ?, ?, ?, ?, 1, ?)`,
    )
      .bind(newId("cup"), user.id, item.name, item.quantity, item.unit, ts)
      .run();
  }
  return handleCupboardGet(env, user);
}

async function tryWorkersAi(env, text) {
  if (!env.AI) return null;
  try {
    const result = await env.AI.run("@cf/meta/llama-3.1-8b-instruct", {
      messages: [
        {
          role: "system",
          content:
            "Extract a recipe as JSON with keys title, summary, serves, minutes, method, ingredients (array of {name, quantity, unit}). No markdown.",
        },
        { role: "user", content: text.slice(0, 4000) },
      ],
    });
    const raw = typeof result === "string" ? result : result?.response || result?.result || "";
    return draftFromModelJson(raw, text);
  } catch {
    return null;
  }
}

export async function handleImportExtract(request, env) {
  const body = await request.json().catch(() => null);
  const text = String(body?.text || "").trim();
  if (text.length < 8) {
    return apiError(400, "empty", "Paste a caption, a link with text, or the recipe itself.");
  }
  const ai = await tryWorkersAi(env, text);
  const draft = ai && ai.ingredients.length ? ai : extractFromCaption(text);
  return json({ ok: true, draft, needs_confirm: true });
}

export async function handleImportConfirm(request, env, user) {
  const body = await request.json().catch(() => null);
  const draft = body?.draft;
  if (!draft?.title) return apiError(400, "bad_draft", "Confirm the recipe on the next screen first.");
  return handleRecipeCreate(
    new Request(request.url, {
      method: "POST",
      headers: { "content-type": "application/json" },
      body: JSON.stringify({ ...draft, published: Boolean(body?.publish) }),
    }),
    env,
    user,
  );
}

export async function handlePackList(env, user) {
  const owned = await purchasedPackIds(env, user.id);
  const { results } = await env.DB.prepare("SELECT * FROM packs WHERE published = 1 ORDER BY created_at DESC").all();
  const packs = [];
  for (const pack of results || []) {
    const { results: links } = await env.DB.prepare("SELECT recipe_id FROM pack_recipes WHERE pack_id = ?")
      .bind(pack.id)
      .all();
    packs.push({
      id: pack.id,
      creator_id: pack.creator_id,
      title: pack.title,
      summary: pack.summary,
      price_pence: Number(pack.price_pence),
      recipe_ids: (links || []).map((l) => l.recipe_id),
      purchased: owned.has(pack.id) || pack.creator_id === user.id,
      mine: pack.creator_id === user.id,
    });
  }
  return json({ ok: true, packs });
}

export async function handlePackCreate(request, env, user) {
  if (!isCreator(user)) return creatorOnlyError();
  const body = await request.json().catch(() => null);
  const title = String(body?.title || "").trim();
  if (title.length < 2) return apiError(400, "bad_title", "Give the pack a name.");
  const unsafe = rejectUnsafeTitle(title);
  if (unsafe) return unsafe;
  const recipeIds = Array.isArray(body?.recipe_ids) ? body.recipe_ids : [];
  if (recipeIds.length === 0) return apiError(400, "empty_pack", "Add at least one of your recipes.");
  for (const rid of recipeIds) {
    const recipe = await env.DB.prepare("SELECT * FROM recipes WHERE id = ? AND author_id = ?")
      .bind(rid, user.id)
      .first();
    if (!recipe) return apiError(400, "not_yours", "Packs can only include your own recipes.");
  }
  const id = newId("pck");
  await env.DB.prepare(
    `INSERT INTO packs (id, creator_id, title, summary, price_pence, published, created_at)
     VALUES (?, ?, ?, ?, ?, 1, ?)`,
  )
    .bind(id, user.id, title, String(body?.summary || ""), clampInt(body?.price_pence, 0, 100000, 0), nowIso())
    .run();
  for (const rid of recipeIds) {
    await env.DB.prepare("INSERT INTO pack_recipes (pack_id, recipe_id) VALUES (?, ?)").bind(id, rid).run();
    // Do not flip exclusivity on attach — creators choose exclusive at recipe create/edit time.
  }
  return json({ ok: true, pack_id: id }, { status: 201 });
}

export async function handlePackPurchase(env, user, id) {
  const pack = await env.DB.prepare("SELECT * FROM packs WHERE id = ?").bind(id).first();
  if (!pack) return apiError(404, "not_found", "That pack is not listed.");
  if (pack.creator_id === user.id) {
    return json({ ok: true, stub: true, already: true, message: "This is your pack." });
  }
  await env.DB.prepare(
    "INSERT OR IGNORE INTO purchases (id, user_id, pack_id, stub, created_at) VALUES (?, ?, ?, 1, ?)",
  )
    .bind(newId("pur"), user.id, id, nowIso())
    .run();
  return json({
    ok: true,
    stub: true,
    purchased: true,
    message: "Demonstration checkout — no card was taken.",
  });
}
