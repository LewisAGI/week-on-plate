CREATE TABLE IF NOT EXISTS users (
  id TEXT PRIMARY KEY,
  email TEXT NOT NULL UNIQUE,
  display_name TEXT NOT NULL,
  password_hash TEXT NOT NULL,
  password_salt TEXT NOT NULL,
  kdf TEXT NOT NULL,
  kdf_iterations INTEGER NOT NULL,
  demo_fixture INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS sessions (
  token TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  expires_at TEXT NOT NULL,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS households (
  user_id TEXT PRIMARY KEY,
  adults INTEGER NOT NULL DEFAULT 2,
  under18s INTEGER NOT NULL DEFAULT 0,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS recipes (
  id TEXT PRIMARY KEY,
  author_id TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT,
  method TEXT,
  serves INTEGER NOT NULL DEFAULT 2,
  minutes INTEGER,
  published INTEGER NOT NULL DEFAULT 0,
  house_recipe INTEGER NOT NULL DEFAULT 0,
  exclusive INTEGER NOT NULL DEFAULT 0,
  source_text TEXT,
  created_at TEXT NOT NULL,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS ingredients (
  id TEXT PRIMARY KEY,
  recipe_id TEXT NOT NULL,
  name TEXT NOT NULL,
  quantity REAL,
  unit TEXT,
  notes TEXT,
  sort_order INTEGER NOT NULL DEFAULT 0
);

CREATE TABLE IF NOT EXISTS saved_recipes (
  user_id TEXT NOT NULL,
  recipe_id TEXT NOT NULL,
  created_at TEXT NOT NULL,
  PRIMARY KEY (user_id, recipe_id)
);

CREATE TABLE IF NOT EXISTS week_slots (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  plan_date TEXT NOT NULL,
  slot TEXT NOT NULL,
  recipe_id TEXT NOT NULL,
  servings REAL,
  cooked INTEGER NOT NULL DEFAULT 0,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS cupboard_items (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  name TEXT NOT NULL,
  quantity REAL,
  unit TEXT,
  in_stock INTEGER NOT NULL DEFAULT 1,
  updated_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS packs (
  id TEXT PRIMARY KEY,
  creator_id TEXT NOT NULL,
  title TEXT NOT NULL,
  summary TEXT,
  price_pence INTEGER NOT NULL DEFAULT 0,
  published INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL
);

CREATE TABLE IF NOT EXISTS pack_recipes (
  pack_id TEXT NOT NULL,
  recipe_id TEXT NOT NULL,
  PRIMARY KEY (pack_id, recipe_id)
);

CREATE TABLE IF NOT EXISTS purchases (
  id TEXT PRIMARY KEY,
  user_id TEXT NOT NULL,
  pack_id TEXT NOT NULL,
  stub INTEGER NOT NULL DEFAULT 1,
  created_at TEXT NOT NULL,
  UNIQUE (user_id, pack_id)
);

CREATE INDEX IF NOT EXISTS idx_ingredients_recipe ON ingredients(recipe_id);
CREATE INDEX IF NOT EXISTS idx_slots_user_date ON week_slots(user_id, plan_date);
CREATE INDEX IF NOT EXISTS idx_cupboard_user ON cupboard_items(user_id);
CREATE INDEX IF NOT EXISTS idx_recipes_published ON recipes(published, exclusive);
