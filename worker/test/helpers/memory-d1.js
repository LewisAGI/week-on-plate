import { readFileSync } from "node:fs";
import { dirname, join } from "node:path";
import { DatabaseSync } from "node:sqlite";
import { fileURLToPath } from "node:url";

const root = join(dirname(fileURLToPath(import.meta.url)), "../..");

export function createMemoryD1() {
  const db = new DatabaseSync(":memory:");
  db.exec(readFileSync(join(root, "migrations/0001_init.sql"), "utf8"));
  db.exec(readFileSync(join(root, "migrations/0002_roles.sql"), "utf8"));
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

export function testEnv(overrides = {}) {
  return {
    DB: createMemoryD1(),
    APP_VERSION: "0.1.1",
    BUILD_SHA: "testdeadbeef",
    LOGIN_ATTEMPT_LIMIT: 20,
    ...overrides,
  };
}
