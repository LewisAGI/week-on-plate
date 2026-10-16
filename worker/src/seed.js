import { DEMO_FIXTURES, demoAccounts, hashPassword, verifyPassword } from "./auth.js";
import { nowIso } from "./util.js";

const HOUSE = [
  {
    id: "rcp_house_lemon_chicken",
    title: "Lemon roast chicken and potatoes",
    summary: "One-tin supper: chicken, potatoes, lemon and garlic.",
    serves: 4,
    minutes: 55,
    method:
      "Heat the oven to 200°C.\nToss potatoes, chicken, lemon, garlic and oil on a tin.\nRoast 45–50 minutes until the chicken is cooked through.\nRest five minutes, then serve.",
    ingredients: [
      { name: "Chicken breast", quantity: 600, unit: "g" },
      { name: "Potatoes", quantity: 800, unit: "g" },
      { name: "Lemons", quantity: 2, unit: "each" },
      { name: "Garlic", quantity: 3, unit: "each" },
      { name: "Olive oil", quantity: 2, unit: "tbsp" },
    ],
  },
  {
    id: "rcp_house_oats",
    title: "Overnight oats with berries",
    summary: "Mix at night, eat in the morning. Quietly high-protein.",
    serves: 2,
    minutes: 5,
    method:
      "Stir oats, yoghurt, milk and honey.\nCover and chill overnight.\nTop with berries in the morning.",
    ingredients: [
      { name: "Rolled oats", quantity: 120, unit: "g" },
      { name: "Greek yoghurt", quantity: 200, unit: "g" },
      { name: "Milk", quantity: 200, unit: "ml" },
      { name: "Honey", quantity: 1, unit: "tbsp" },
      { name: "Berries", quantity: 150, unit: "g" },
    ],
  },
  {
    id: "rcp_house_chickpea",
    title: "Chickpea and spinach stew",
    summary: "A pan of chickpeas, tomatoes and greens. Bread on the side if you like.",
    serves: 4,
    minutes: 30,
    method:
      "Soften onion and garlic in oil.\nAdd tomatoes, chickpeas, cumin and a splash of water.\nSimmer 15 minutes.\nFold in spinach until wilted.\nSeason.",
    ingredients: [
      { name: "Onions", quantity: 1, unit: "each" },
      { name: "Garlic", quantity: 2, unit: "each" },
      { name: "Tinned tomatoes", quantity: 400, unit: "g" },
      { name: "Chickpeas", quantity: 400, unit: "g" },
      { name: "Spinach", quantity: 200, unit: "g" },
      { name: "Olive oil", quantity: 1, unit: "tbsp" },
      { name: "Cumin", quantity: 1, unit: "tsp" },
    ],
  },
  {
    id: "rcp_house_salmon",
    title: "Salmon, broccoli and rice",
    summary: "A plate that looks after itself: fish, greens, rice.",
    serves: 2,
    minutes: 25,
    method:
      "Cook the rice.\nSteam broccoli.\nPan-fry salmon in a little oil, 4 minutes a side.\nLemon over the top.",
    ingredients: [
      { name: "Salmon", quantity: 300, unit: "g" },
      { name: "Broccoli", quantity: 300, unit: "g" },
      { name: "Basmati rice", quantity: 160, unit: "g" },
      { name: "Olive oil", quantity: 1, unit: "tbsp" },
      { name: "Lemons", quantity: 1, unit: "each" },
    ],
  },
  {
    id: "rcp_house_chilli",
    title: "Turkey chilli",
    summary: "A weeknight chilli that freezes cleanly.",
    serves: 4,
    minutes: 40,
    method:
      "Brown the turkey.\nAdd onion, garlic, tomatoes, beans, chilli powder and paprika.\nSimmer 25 minutes.\nTaste for salt.",
    ingredients: [
      { name: "Turkey mince", quantity: 500, unit: "g" },
      { name: "Onions", quantity: 1, unit: "each" },
      { name: "Garlic", quantity: 2, unit: "each" },
      { name: "Tinned tomatoes", quantity: 400, unit: "g" },
      { name: "Kidney beans", quantity: 400, unit: "g" },
      { name: "Chilli powder", quantity: 1, unit: "tsp" },
      { name: "Paprika", quantity: 1, unit: "tsp" },
    ],
  },
];

const PACK = [
  {
    id: "rcp_pack_miso",
    title: "Miso salmon traybake",
    summary: "Salmon and greens under a miso glaze. From the Weeknight plates pack.",
    serves: 2,
    minutes: 30,
    exclusive: 1,
    method:
      "Mix miso, honey and soy.\nCoat the salmon.\nRoast with broccoli at 200°C for 18 minutes.\nServe with rice.",
    ingredients: [
      { name: "Salmon", quantity: 300, unit: "g" },
      { name: "Miso", quantity: 1, unit: "tbsp" },
      { name: "Honey", quantity: 1, unit: "tsp" },
      { name: "Soy sauce", quantity: 1, unit: "tbsp" },
      { name: "Broccoli", quantity: 250, unit: "g" },
      { name: "Basmati rice", quantity: 160, unit: "g" },
    ],
  },
  {
    id: "rcp_pack_pancakes",
    title: "Cottage cheese pancakes",
    summary: "A weekend breakfast that still earns its keep midweek.",
    serves: 2,
    minutes: 20,
    exclusive: 1,
    method:
      "Blend cottage cheese, eggs and oats.\nFry spoonfuls in a lightly oiled pan.\nBerries on top.",
    ingredients: [
      { name: "Cottage cheese", quantity: 200, unit: "g" },
      { name: "Eggs", quantity: 2, unit: "each" },
      { name: "Rolled oats", quantity: 80, unit: "g" },
      { name: "Berries", quantity: 100, unit: "g" },
      { name: "Olive oil", quantity: 1, unit: "tsp" },
    ],
  },
];

const syncedFixturePasswords = new Set();

export function resetFixturePasswordSync() {
  syncedFixturePasswords.clear();
}

async function syncFixturePassword(env, account) {
  if (!account.password || syncedFixturePasswords.has(account.id)) return;
  syncedFixturePasswords.add(account.id);
  const user = await env.DB.prepare("SELECT * FROM users WHERE id = ?").bind(account.id).first();
  if (!user) return;
  if (await verifyPassword(user, account.password)) return;
  const fresh = await hashPassword(account.password);
  await env.DB.prepare(
    `UPDATE users SET password_hash = ?, password_salt = ?, kdf = ?, kdf_iterations = ?
     WHERE id = ? AND demo_fixture = 1`,
  )
    .bind(fresh.hash, fresh.salt, fresh.kdf, fresh.kdf_iterations, account.id)
    .run();
}

async function insertUser(env, account) {
  if (!account.password) return;
  const fresh = await hashPassword(account.password);
  const ts = nowIso();
  await env.DB.prepare(
    `INSERT OR IGNORE INTO users
      (id, email, display_name, password_hash, password_salt, kdf, kdf_iterations, demo_fixture, role, created_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?)`,
  )
    .bind(
      account.id,
      account.email,
      account.display_name,
      fresh.hash,
      fresh.salt,
      fresh.kdf,
      fresh.kdf_iterations,
      account.role === "creator" ? "creator" : "buyer",
      ts,
    )
    .run();
  await env.DB.prepare(
    "INSERT OR IGNORE INTO households (user_id, adults, under18s, updated_at) VALUES (?, 2, 0, ?)",
  )
    .bind(account.id, ts)
    .run();
}

async function insertRecipe(env, recipe, authorId, house) {
  const ts = nowIso();
  await env.DB.prepare(
    `INSERT OR IGNORE INTO recipes
      (id, author_id, title, summary, method, serves, minutes, published, house_recipe, exclusive, source_text, created_at, updated_at)
     VALUES (?, ?, ?, ?, ?, ?, ?, 1, ?, ?, NULL, ?, ?)`,
  )
    .bind(
      recipe.id,
      authorId,
      recipe.title,
      recipe.summary,
      recipe.method,
      recipe.serves,
      recipe.minutes,
      house ? 1 : 0,
      recipe.exclusive ? 1 : 0,
      ts,
      ts,
    )
    .run();
  let i = 0;
  for (const ing of recipe.ingredients) {
    i += 1;
    await env.DB.prepare(
      `INSERT OR IGNORE INTO ingredients (id, recipe_id, name, quantity, unit, notes, sort_order)
       VALUES (?, ?, ?, ?, ?, NULL, ?)`,
    )
      .bind(`${recipe.id}_ing_${i}`, recipe.id, ing.name, ing.quantity, ing.unit, i)
      .run();
  }
}

let seedPromise = null;

export async function ensureSeeded(env) {
  if (!env?.DB) return;
  if (!seedPromise) {
    seedPromise = seedNow(env).finally(() => {
      seedPromise = null;
    });
  }
  return seedPromise;
}

async function ensureFixtureRoles(env) {
  try {
    await env.DB.prepare("UPDATE users SET role = ? WHERE id = ?")
      .bind("creator", DEMO_FIXTURES.creator.id)
      .run();
    await env.DB.prepare("UPDATE users SET role = ? WHERE id = ?")
      .bind("buyer", DEMO_FIXTURES.buyer.id)
      .run();
  } catch {
    // role column is added by migration 0002
  }
}

async function refreshSeededMethods(env) {
  for (const recipe of [...HOUSE, ...PACK]) {
    try {
      const row = await env.DB.prepare("SELECT method FROM recipes WHERE id = ?").bind(recipe.id).first();
      if (row?.method && !String(row.method).includes("\n")) {
        await env.DB.prepare("UPDATE recipes SET method = ? WHERE id = ?").bind(recipe.method, recipe.id).run();
      }
    } catch {
      // recipes table may not exist before migrate
    }
  }
}

async function seedNow(env) {
  const accounts = demoAccounts(env);
  await ensureFixtureRoles(env);
  await refreshSeededMethods(env);
  await syncFixturePassword(env, accounts.creator);
  await syncFixturePassword(env, accounts.buyer);
  const existing = await env.DB.prepare("SELECT id FROM users WHERE id = ?")
    .bind(DEMO_FIXTURES.creator.id)
    .first();
  if (existing) return { seeded: false };
  if (!accounts.creator.password || !accounts.buyer.password) return { seeded: false };

  await insertUser(env, accounts.creator);
  await insertUser(env, accounts.buyer);

  for (const recipe of HOUSE) {
    await insertRecipe(env, recipe, DEMO_FIXTURES.creator.id, true);
  }
  for (const recipe of PACK) {
    await insertRecipe(env, recipe, DEMO_FIXTURES.creator.id, false);
  }

  const ts = nowIso();
  await env.DB.prepare(
    `INSERT OR IGNORE INTO packs (id, creator_id, title, summary, price_pence, published, created_at)
     VALUES (?, ?, ?, ?, ?, 1, ?)`,
  )
    .bind(
      "pck_weeknight",
      DEMO_FIXTURES.creator.id,
      "Weeknight plates",
      "Two midweek recipes from Sam: miso salmon and cottage cheese pancakes.",
      900,
      ts,
    )
    .run();
  await env.DB.prepare("INSERT OR IGNORE INTO pack_recipes (pack_id, recipe_id) VALUES (?, ?)")
    .bind("pck_weeknight", "rcp_pack_miso")
    .run();
  await env.DB.prepare("INSERT OR IGNORE INTO pack_recipes (pack_id, recipe_id) VALUES (?, ?)")
    .bind("pck_weeknight", "rcp_pack_pancakes")
    .run();

  return { seeded: true };
}
