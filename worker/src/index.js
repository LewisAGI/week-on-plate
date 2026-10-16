import { handleLogin, handleLogout, handleMe, identify } from "./auth.js";
import {
  handleColdStart,
  handleCupboardAdd,
  handleCupboardAdjust,
  handleCupboardGet,
  handleCupboardPatch,
  handleCupboardPut,
  handleCupboardScan,
  handleHouseholdGet,
  handleHouseholdPut,
  handleImportConfirm,
  handleImportExtract,
  handlePackCreate,
  handlePackList,
  handlePackPurchase,
  handleRecipeCreate,
  handleRecipeGet,
  handleRecipeList,
  handleRecipePublish,
  handleRecipeSave,
  handleRecipeUpdate,
  handleShopping,
  handleWeekCooked,
  handleWeekDelete,
  handleWeekGet,
  handleWeekPut,
} from "./data.js";
import { TEEN_TIP } from "./domain/scale.js";
import { ensureSeeded } from "./seed.js";
import { resolveBuild, resolveVersion, SERVICE_NAME, apiError, json, nowIso, withCors } from "./util.js";

async function health(env) {
  await ensureSeeded(env);
  let accounts = { total: 0, fixtures: 0 };
  try {
    const row = await env.DB.prepare(
      `SELECT COUNT(*) AS total, SUM(CASE WHEN demo_fixture = 1 THEN 1 ELSE 0 END) AS fixtures FROM users`,
    ).first();
    accounts = { total: Number(row?.total) || 0, fixtures: Number(row?.fixtures) || 0 };
  } catch {
    accounts = { total: 0, fixtures: 0, error: "migrate" };
  }
  return json({
    ok: true,
    service: SERVICE_NAME,
    version: resolveVersion(env),
    build: resolveBuild(env),
    stage: "demonstration",
    auth: "bearer token or session cookie, password login",
    demo_accounts:
      "enabled when DEMO_CREATOR_PASSWORD and DEMO_BUYER_PASSWORD are set on the Worker",
    accounts,
    db: accounts.error ? "needs_migration" : "ok",
    ts: nowIso(),
  });
}

function match(path, pattern) {
  const a = path.split("/").filter(Boolean);
  const b = pattern.split("/").filter(Boolean);
  if (a.length !== b.length) return null;
  const params = {};
  for (let i = 0; i < a.length; i++) {
    if (b[i].startsWith(":")) params[b[i].slice(1)] = decodeURIComponent(a[i]);
    else if (a[i] !== b[i]) return null;
  }
  return params;
}

export default {
  async fetch(request, env) {
    if (request.method === "OPTIONS") {
      return withCors(new Response(null, { status: 204 }), request);
    }

    const url = new URL(request.url);
    const path = url.pathname.replace(/\/+$/, "") || "/";
    const method = request.method;

    try {
      if (path === "/" && method === "GET") {
        return withCors(
          json({
            ok: true,
            service: SERVICE_NAME,
            hint: "WeekOnPlate API. Open the Flutter app, or GET /api/health.",
          }),
          request,
        );
      }

      if (path === "/api/health" && method === "GET") {
        return withCors(await health(env), request);
      }

      await ensureSeeded(env);

      if (path === "/api/auth/login" && method === "POST") {
        return withCors(await handleLogin(request, env), request);
      }
      if (path === "/api/auth/logout" && method === "POST") {
        return withCors(await handleLogout(request, env), request);
      }
      if (path === "/api/auth/me" && method === "GET") {
        return withCors(await handleMe(request, env), request);
      }

      const user = await identify(request, env);
      if (!user) {
        return withCors(
          apiError(401, "not_authenticated", "You are not signed in.", {
            sign_in: "POST /api/auth/login with an email address and a password.",
          }),
          request,
        );
      }

      if (path === "/api/household" && method === "GET") {
        return withCors(await handleHouseholdGet(env, user), request);
      }
      if (path === "/api/household" && method === "PUT") {
        return withCors(await handleHouseholdPut(request, env, user), request);
      }
      if (path === "/api/recipes" && method === "GET") {
        return withCors(await handleRecipeList(url, env, user), request);
      }
      if (path === "/api/recipes" && method === "POST") {
        return withCors(await handleRecipeCreate(request, env, user), request);
      }

      let p = match(path, "/api/recipes/:id");
      if (p && method === "GET") return withCors(await handleRecipeGet(env, user, p.id), request);
      if (p && method === "PUT") return withCors(await handleRecipeUpdate(request, env, user, p.id), request);

      p = match(path, "/api/recipes/:id/publish");
      if (p && method === "POST") return withCors(await handleRecipePublish(env, user, p.id), request);

      p = match(path, "/api/recipes/:id/save");
      if (p && method === "POST") return withCors(await handleRecipeSave(env, user, p.id, true), request);
      if (p && method === "DELETE") return withCors(await handleRecipeSave(env, user, p.id, false), request);

      if (path === "/api/saved" && method === "GET") {
        url.searchParams.set("scope", "saved");
        return withCors(await handleRecipeList(url, env, user), request);
      }

      if (path === "/api/week" && method === "GET") {
        return withCors(await handleWeekGet(url, env, user), request);
      }
      if (path === "/api/week/slots" && method === "PUT") {
        return withCors(await handleWeekPut(request, env, user), request);
      }
      p = match(path, "/api/week/slots/:id");
      if (p && method === "DELETE") return withCors(await handleWeekDelete(env, user, p.id), request);
      p = match(path, "/api/week/slots/:id/cooked");
      if (p && method === "POST") return withCors(await handleWeekCooked(env, user, p.id), request);

      if (path === "/api/shopping" && method === "GET") {
        return withCors(await handleShopping(url, env, user), request);
      }

      if (path === "/api/cupboard" && method === "GET") {
        return withCors(await handleCupboardGet(env, user), request);
      }
      if (path === "/api/cupboard" && method === "PUT") {
        return withCors(await handleCupboardPut(request, env, user), request);
      }
      if (path === "/api/cupboard/adjust" && method === "POST") {
        return withCors(await handleCupboardAdjust(request, env, user), request);
      }
      if (path === "/api/cupboard/cold-start" && method === "POST") {
        return withCors(await handleColdStart(request, env, user), request);
      }
      if (path === "/api/cupboard/items" && method === "POST") {
        return withCors(await handleCupboardAdd(request, env, user), request);
      }
      if (path === "/api/cupboard/scan" && method === "POST") {
        return withCors(await handleCupboardScan(request, env, user), request);
      }
      p = match(path, "/api/cupboard/:id");
      if (p && method === "PATCH") return withCors(await handleCupboardPatch(request, env, user, p.id), request);

      if (path === "/api/import/extract" && method === "POST") {
        return withCors(await handleImportExtract(request, env), request);
      }
      if (path === "/api/import/confirm" && method === "POST") {
        return withCors(await handleImportConfirm(request, env, user), request);
      }

      if (path === "/api/packs" && method === "GET") {
        return withCors(await handlePackList(env, user), request);
      }
      if (path === "/api/packs" && method === "POST") {
        return withCors(await handlePackCreate(request, env, user), request);
      }
      p = match(path, "/api/packs/:id/purchase");
      if (p && method === "POST") return withCors(await handlePackPurchase(env, user, p.id), request);

      if (path === "/api/meta" && method === "GET") {
        return withCors(json({ ok: true, teen_tip: TEEN_TIP }), request);
      }

      return withCors(apiError(404, "not_found", `${method} ${path} is not served.`), request);
    } catch (err) {
      console.error("week-on-plate", err);
      return withCors(apiError(500, "server_error", "Something went wrong on the server."), request);
    }
  },
};
