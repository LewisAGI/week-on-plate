import { readdirSync, readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "../..");

export function createMemoryD1() {
  const db = new DatabaseSync(":memory:");
  const migrationsDir = join(root, "migrations");
  for (const name of readdirSync(migrationsDir)
    .filter((file) => file.endsWith(".sql"))
    .sort()) {
    db.exec(readFileSync(join(migrationsDir, name), "utf8"));
  }
  return {
    prepare(sql) {
      return {
        _params: [],
        bind(...params) {
          this._params = params;
          return this;
        },
        async first() {
          const row = db.prepare(sql).get(...this._params);
          return row ?? null;
        },
        async all() {
          return { results: db.prepare(sql).all(...this._params) };
        },
        async run() {
          const info = db.prepare(sql).run(...this._params);
          return { success: true, meta: { changes: info.changes } };
        },
      };
    },
  };
}

function fixturePassword(role) {
  return ["fixture", role, "local", "only"].join("-");
}

export function testEnv(overrides = {}) {
  return {
    DB: createMemoryD1(),
    APP_VERSION: "0.1.2",
    BUILD_SHA: "testdeadbeef",
    LOGIN_ATTEMPT_LIMIT: 20,
    DEMO_CREATOR_PASSWORD: fixturePassword("creator"),
    DEMO_BUYER_PASSWORD: fixturePassword("buyer"),
    ...overrides,
  };
}
