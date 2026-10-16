# Public audit

**Verdict: BLOCKED**

HEAD no longer contains the production D1 database id, the personal `workers.dev` hostname, or the live demonstration passwords. Those values remain in git history. History was not rewritten. The demonstration passwords still authenticate on the previously documented Worker until they are rotated, so this repository is not safe to make public yet.

## What to do before making the repository public

1. Choose new demonstration passwords. Do not reuse the values that appear in history.
2. Set them on the existing Worker and redeploy so the fixture password hashes refresh:

   ```bash
   cd worker
   npx wrangler secret put DEMO_CREATOR_PASSWORD
   npx wrangler secret put DEMO_BUYER_PASSWORD
   npx wrangler deploy
   ```

   The next request updates `demo_fixture` users when those secrets are present and do not match the stored hash.
3. Optional: the production D1 database id is still in history. It is not an API token. `CLOUDFLARE_API_TOKEN` was never committed, so the id alone cannot read the database. If the id itself should not be public, create a new D1 database and store the new id only as the GitHub secret `CLOUDFLARE_D1_DATABASE_ID`.

## How this was scanned

- Tool: gitleaks 8.28.0, `gitleaks detect --source . --log-opts="--all"` (every reachable commit, not only HEAD).
- A second pass read every text blob in all 7 commits reachable before this change and grepped for API keys, tokens, Cloudflare account ids (32 hex characters), wrangler secret values, `.env` files, emails, phone numbers, street addresses, postcodes, and personal names.
- Follow-up gitleaks on the tree after the HEAD cleanup is recorded at the bottom.

Commits scanned:

| Commit | Subject |
| --- | --- |
| `f58f9ef` | chore: initial commit |
| `de6ac03` | Build WeekOnPlate MVP (branch `cursor/week-on-plate-mvp-d1cd`) |
| `e07eb3d` | WeekOnPlate MVP |
| `d4b2d84` | Fix Itachi adversarial findings |
| `1bdc480` | Merge pull request #2 |
| `b1fcef2` | This week day strip |
| `fbe5e7c` | Merge pull request #3 (previous HEAD) |

## Findings

| # | What | File | Commit | Severity | Where |
| --- | --- | --- | --- | --- | --- |
| 1 | Live demonstration passwords for the creator and buyer fixture accounts. gitleaks rule `generic-api-key` reported the buyer password in `worker/src/auth.js`. The creator password is the same class and was hardcoded beside it, in the login screen, and in `README.md`. | `worker/src/auth.js`, `app/lib/screens/login_screen.dart`, `README.md` | Introduced in `de6ac03` and `e07eb3d`. Present in `d4b2d84`, `b1fcef2`, and the trees of `1bdc480` and `fbe5e7c`. | High. These strings sign in to the Worker documented in those commits. | History-only. Removed from HEAD. **Rotate** on the live Worker. |
| 2 | Production D1 `database_id` (UUID, not a Cloudflare account id). | `worker/wrangler.jsonc`, `README.md` | Same commits as finding 1 (`de6ac03`, `e07eb3d`, and descendants through `fbe5e7c`). | Medium. Resource identifier. Not an access token. | History-only. HEAD now has the placeholder `00000000-0000-0000-0000-000000000000`. No API token to rotate. Optional new database, above. |
| 3 | Personal workers.dev hostname containing a real name, used as the app default and a CORS allowlist entry. | `README.md`, `app/lib/api/api.dart`, `worker/src/util.js`, `worker/test/security.test.js`, `worker/test/cupboard-api.test.js` | Same commits as finding 1. | Low. Public hostname, not a credential. | History-only. HEAD defaults to `http://127.0.0.1:8787`. Nothing to rotate. |
| 4 | Git author identity `Lewis-Godfrey <106411939+Lewis-Godfrey@users.noreply.github.com>` on `f58f9ef`, `e07eb3d`, `1bdc480`, `fbe5e7c`. | Commit metadata, not a file. | Those commits. | Info. GitHub noreply address, not a private inbox. | History-only. Not rewritten. |

The literal password and database id are intentionally not repeated in this file, so HEAD does not gain a fresh copy.

## Reviewed and not treated as findings

- No Cloudflare account id (32 hex characters). No API token, private key, Slack token, GitHub token, or `sk-` key in any commit.
- No `.env`, `.dev.vars`, or wrangler secret *values*. CI only names the GitHub secrets `CF_API_TOKEN`, `CLOUDFLARE_ACCOUNT_ID`, and (after this change) `CLOUDFLARE_D1_DATABASE_ID`.
- No phone numbers, street addresses, or postcodes. Digit runs inside `project.pbxproj` and `pubspec.lock` matched a phone-shaped pattern and are Xcode ids and package checksums.
- Icon filenames such as `Icon-App-20x20@2x.png` matched an email-shaped pattern. They are not emails.
- Fixture emails `creator@weekonplate.demo` and `buyer@weekonplate.demo` are demonstration addresses, not personal inboxes. They remain, because the product signs in with them.
- Display names Sam Taylor and Jordan Ellis are fictional fixture names.
- Household default of 2 adults and 0 under-18s is a product default, not a record of a real household.
- Test-only Worker passwords are built in `worker/test/helpers/memory-d1.js` for the in-memory database. They are not the historical live passwords and are not deployed.

## HEAD cleanup

- Fixture passwords are read from `DEMO_CREATOR_PASSWORD` and `DEMO_BUYER_PASSWORD` (`.dev.vars` locally, `wrangler secret put` in production). Source defaults are empty.
- `.gitignore` ignores `.env`, `.dev.vars`, and key files, and keeps `.dev.vars.example`.
- `wrangler.jsonc` keeps a placeholder database id. Deploy substitutes `CLOUDFLARE_D1_DATABASE_ID` in CI and does not commit it.
- The Flutter default API base is local wrangler, not a personal hostname.

## Follow-up scan

After the HEAD cleanup, `gitleaks detect --no-git` on the working tree reported **0 findings**.

`gitleaks detect --log-opts="--all"` still reports the buyer fixture password (rule `generic-api-key`) in `worker/src/auth.js` at `de6ac03` and `e07eb3d`. That is the history copy of finding 1. This change does not rewrite those commits. The creator fixture password sits in the same historical files and was removed from HEAD with it.
