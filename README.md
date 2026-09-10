# WeekOnPlate

Working title (Lewis may rename). Creator-led meal OS: close the gap between a saved reel and actually cooking this week.

Gym- and macro-friendly without being gym-branded. White background, green type and accents. British English.

Monorepo:

- `/app` — Flutter (iOS Simulator first; Android-capable)
- `/worker` — Cloudflare Worker + D1

Live API (when deployed): `https://week-on-plate.lewismgodfrey.workers.dev`

## Demonstration accounts

Published fixture passwords, same idea as position-manager. Seeded on migrate / first request.

| | Email | Password | Role |
| --- | --- | --- | --- |
| **A** | `creator@weekonplate.demo` | `WeekOnPlate-Creator-26` | Creator — publish recipes and packs |
| **B** | `buyer@weekonplate.demo` | `WeekOnPlate-Buyer-26` | Browse, save, plan, cupboard, stub-buy |

These are demonstration logins. Do not reuse them anywhere real.

The API stores `role` on each user. Buyers may create and publish ordinary recipes. Only creators may set `exclusive: true` or `POST /api/packs` — buyers receive `403`. Attaching a recipe to a pack does not flip its exclusivity; creators choose that when they write the recipe.

CORS allowlists the workers.dev host and localhost / emulator origins. Arbitrary origins are not reflected when credentials are on. The Flutter app should send a Bearer token.

## How Lewis runs the Flutter app on the iOS Simulator

On a Mac with Xcode and the Flutter SDK (`flutter doctor` should show a connected Simulator):

```bash
cd app
flutter pub get

# Default: talk to the deployed Worker
flutter run

# Or point at local wrangler (http://127.0.0.1:8787)
flutter run --dart-define=API_BASE=http://127.0.0.1:8787
```

Pick an iPhone simulator when prompted, or:

```bash
open -a Simulator
flutter devices
flutter run -d "iPhone 16"
```

The login screen can fill account A or B. After sign-in you get Week, Recipes, Shop, Cupboard, More.

### Point the app at a Worker

| Target | `API_BASE` |
| --- | --- |
| Deployed | `https://week-on-plate.lewismgodfrey.workers.dev` (this is the app default) |
| Local wrangler | `http://127.0.0.1:8787` |

```bash
flutter run --dart-define=API_BASE=https://week-on-plate.lewismgodfrey.workers.dev
```

Android is kept capable (`flutter run` on an emulator or device). For the Android emulator, localhost is `http://10.0.2.2:8787`. App Store / Play listing are out of scope.

## Worker: local and deploy

```bash
cd worker
npm install
npx wrangler d1 migrations apply week-on-plate-db --local
npx wrangler dev
```

Health:

```bash
curl -sS http://127.0.0.1:8787/api/health
```

### Deploy notes (Worker + D1)

D1 database `week-on-plate-db` (id `b27e2cb2-a847-41ed-96ff-edae9b59acbc`) is already created on the Lewis Cloudflare account.

```bash
cd worker
npx wrangler d1 migrations apply week-on-plate-db --remote
npx wrangler deploy
```

Expected workers.dev host: `https://week-on-plate.lewismgodfrey.workers.dev`

GitHub Actions (`.github/workflows/ci.yml`) runs Worker tests, `flutter analyze`, and `flutter test`. On push to `main` it deploys when these secrets exist on the repo or org:

- `CF_API_TOKEN` — mapped to Wrangler as `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`

If those secrets are missing, CI still goes green and skips deploy. The Worker remains wrangler-ready.

Workers AI is bound as `AI`. Import prefers a cheap Llama extract and always falls back to a deterministic caption parser, so the MVP works without an LLM key.

## Seeded house recipes and a pack

On first boot the Worker writes:

- Five public house recipes (lemon chicken, overnight oats, chickpea stew, salmon and rice, turkey chilli)
- A creator pack, **Weeknight plates** (£9 stub): miso salmon traybake + cottage cheese pancakes (exclusive until purchased)

Household default: **2 adults**, 0 under-18s. The household screen explains that older teenagers often eat like adults — count them as adults if that is your house.

## Smoke path (A then B)

1. Sign in as **A**. Create a recipe (publish it). Create a pack from More → Creator packs.
2. Sign out. Sign in as **B**.
3. Browse / save a house recipe. Add meals to **This week**.
4. Open **Shop** — merged ingredients, cupboard-aware, no supermarket prices.
5. **Cupboard** — cold-start staples; untick as used. Mark a meal cooked and accept stock adjustments.
6. **More → Import** — paste a caption (a sample is pre-filled) → confirm screen → save.
7. Open a day on the week plan and read **macros** (kcal, protein, carbs, fat, sugar).
8. **Creator packs** → stub-buy **Weeknight plates**. Exclusive recipes then appear under Browse.

## Tests

```bash
cd worker && npm test
cd ../app && flutter analyze && flutter test
```

Core domain covered on both sides: scale, shopping merge, macros, cupboard.

## Out of scope

Grocery API, Spoonacular dumps, App Store submit, equity / payouts, Android Play listing, live Stripe.

## Product copy note

British English throughout the app and this README.
