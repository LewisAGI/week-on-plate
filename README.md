# WeekOnPlate

Creator-led meal OS: close the gap between a saved reel and actually cooking this week. Working title — Lewis may rename.

Gym- and macro-friendly without being gym-branded. White background, green type and accents. British English.

v1 is a **self-hosted** Flutter app plus a Cloudflare Worker. There is no App Store or Play Store listing.

## Features

- **This week** — one scrolling list, a day at a time, with meals, macros, and a mini fullness grid.
- **Recipes** — browse, save, write, and import a caption into a confirmable draft. House recipes and creator packs.
- **Groceries** — a shopping list from the week, minus the cupboard. No checkout and no supermarket prices.
- **Cupboard** — cold-start staples, add what you already own, or scan a paper list.
- **Household scale** — recipes scale to the number of people at the table. The default is two adults.

## Clone here — not Documents/Grok

Put the project on the local disk:

```bash
mkdir -p ~/Developer
git clone https://github.com/LewisAGI/week-on-plate.git ~/Developer/week-on-plate
cd ~/Developer/week-on-plate
```

**Do not** clone into `~/Documents/Grok` (or any iCloud Desktop & Documents folder). The iCloud File Provider breaks iOS codesign when Xcode / Flutter writes build products under iCloud.

Expected local toolchain: **Flutter 3.47**, **Xcode** (iOS), and **Node 22** for the Worker.

## Run on iPhone (Mac)

On a Mac with Xcode and the Flutter SDK (`flutter doctor` should show a connected iPhone or Simulator):

```bash
cd ~/Developer/week-on-plate/app
flutter pub get
```

Start the Worker first (below), then:

```bash
flutter run --dart-define=API_BASE=http://127.0.0.1:8787
```

Pick an iPhone simulator when prompted, or:

```bash
open -a Simulator
flutter devices
flutter run -d "iPhone 16" --dart-define=API_BASE=http://127.0.0.1:8787
```

The app talks to `http://127.0.0.1:8787` unless you pass `API_BASE`.

First-run on a physical iPhone: open `app/ios/Runner.xcworkspace` in Xcode and pick a development team. The iOS Simulator does not need a team.

Fill the demonstration emails from the login screen. Passwords are the ones you set on the Worker (see below), passed through when you want the fill buttons to type them:

```bash
flutter run \
  --dart-define=API_BASE=http://127.0.0.1:8787 \
  --dart-define=DEMO_CREATOR_PASSWORD='your-creator-password' \
  --dart-define=DEMO_BUYER_PASSWORD='your-buyer-password'
```

Android stays capable (`flutter run` on an emulator or device). For the Android emulator, the host machine is `http://10.0.2.2:8787`.

## Worker — local

```bash
cd ~/Developer/week-on-plate/worker
npm install
cp .dev.vars.example .dev.vars
```

Edit `.dev.vars` and set `DEMO_CREATOR_PASSWORD` and `DEMO_BUYER_PASSWORD` (12 characters or more). That file is gitignored.

Create your own D1 database and paste the id into `worker/wrangler.jsonc` in place of the placeholder `00000000-0000-0000-0000-000000000000`. Do not commit a production id.

```bash
npx wrangler d1 create week-on-plate-db
npx wrangler d1 migrations apply week-on-plate-db --local
npx wrangler dev
```

Health:

```bash
curl -sS http://127.0.0.1:8787/api/health
```

On first boot the Worker writes five public house recipes, a creator pack (**Weeknight plates**, £9 stub), and the two demonstration accounts — only if those passwords are set.

| | Email | Role |
| --- | --- | --- |
| **A** | `creator@weekonplate.demo` | Creator — publish recipes and packs |
| **B** | `buyer@weekonplate.demo` | Browse, save, plan, cupboard, stub-buy |

Buyers may create and publish ordinary recipes. Only creators may set `exclusive: true` or `POST /api/packs`.

## Self-host

```bash
cd worker
npx wrangler secret put DEMO_CREATOR_PASSWORD
npx wrangler secret put DEMO_BUYER_PASSWORD
npx wrangler d1 migrations apply week-on-plate-db --remote
npx wrangler deploy
```

`CLOUDFLARE_API_TOKEN` and `CLOUDFLARE_ACCOUNT_ID` stay in the environment. They are not written into the repo. Wrangler reads them from the shell.

Point the app at your Worker:

```bash
cd app
flutter run --dart-define=API_BASE=https://<your-worker>.workers.dev
```

GitHub Actions (`.github/workflows/ci.yml`) runs Worker tests, `flutter analyze`, and `flutter test`. On push to `main` it deploys when these secrets exist on the repo or org:

- `CF_API_TOKEN` — mapped to Wrangler as `CLOUDFLARE_API_TOKEN`
- `CLOUDFLARE_ACCOUNT_ID`
- `CLOUDFLARE_D1_DATABASE_ID` — substituted into `wrangler.jsonc` during the job, not committed

If any of those are missing, CI still goes green and skips deploy.

Workers AI is bound as `AI`. Import prefers a cheap Llama extract and always falls back to a deterministic caption parser, so the app works without an LLM key.

CORS allows the Worker’s own origin plus localhost and the Android emulator host. Arbitrary origins are not reflected when credentials are on. The Flutter app sends a Bearer token.

## Smoke path

1. Sign in as **A**. Create a recipe (publish it). Create a pack from More → Creator packs.
2. Sign out. Sign in as **B**.
3. Browse or save a house recipe. Add meals to **This week**.
4. Open **Groceries** — a list from the week plan, cupboard-aware.
5. **Cupboard** — cold-start staples, manual add, or scan a shopping list. Untick as used. Mark a meal cooked and accept stock adjustments.
6. **More → Import** — paste a caption → confirm → save.
7. **Creator packs** → stub-buy **Weeknight plates**.

## Tests

```bash
cd worker && npm test
cd ../app && flutter analyze && flutter test
```

## Out of scope

Grocery API, Spoonacular dumps, App Store submit, equity / payouts, Android Play listing, live Stripe.
