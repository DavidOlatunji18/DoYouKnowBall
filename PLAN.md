# Do You Know Ball? — Build Plan for Claude Code

Read this whole file first, then work through the phases in order. Do not skip ahead.

## Project

A cross-platform mobile sports trivia app.

- **Mobile:** Flutter (`/mobile`)
- **API:** ASP.NET Core Web API, .NET 8, EF Core (`/api`)
- **Database:** SQL Server (local Docker for dev, Azure SQL for prod)
- **Hosting:** Azure App Service (API), Azure SQL (DB)
- **Later (post-MVP):** AWS S3 for question images / team logos

Target: a working MVP by Sunday. Optimize for a complete vertical slice (register, play, score, leaderboard) over breadth.

## MVP scope

**In:** email/password auth (JWT), 2 sports (Soccer, NFL) with 2-3 categories each (Soccer: European Top 5 Leagues, Internationals), 10-question rounds with 4 multiple-choice answers, server-side scoring, saved game history, per-sport leaderboard.

**Out (do not build yet):** other 3 sports, S3, timers, streaks, social login, friends/multiplayer, admin panel, push notifications.

## Ground rules for Claude Code

1. Work one phase at a time. At the end of each phase, run the build/tests, fix failures, and `git commit` with a clear message.
2. Never commit secrets. JWT key and connection strings come from environment variables / user-secrets locally and App Service settings in prod. Add `.gitignore` entries for `appsettings.Development.json` secrets, `*.env`, and keystores.
3. Passwords: hash with `PasswordHasher<User>`. Never log passwords or tokens.
4. The quiz endpoint must NOT return correct answers. Scoring happens server-side.
5. Before creating any paid Azure resource, stop and ask me.
6. Keep code simple and conventional: controllers + services + EF Core, DTOs for all request/response shapes, no extra abstraction layers.
7. After finishing each phase, update `README.md` with how to run what exists so far.
8. If something is ambiguous, pick the simplest option, note it in `DECISIONS.md`, and keep going. Only stop to ask for things listed under "Manual steps".

## Manual steps (things only I can do)

Stop and tell me clearly when you reach one of these:
- `az login` and choosing the Azure subscription
- Approving creation of Azure resources
- Apple Developer / Google Play account actions
- Reviewing the seeded questions for factual accuracy (flag any you are unsure about)

## API contract (build both sides against this)

Base URL: `http://localhost:5050` locally. Android emulator reaches the host at `http://10.0.2.2:5050`. (Port moved from 5000, which macOS AirPlay Receiver occupies; see DECISIONS.md.) All routes except `/auth/*` require `Authorization: Bearer <jwt>`.

| Method | Route | Request | Response |
|---|---|---|---|
| POST | `/auth/register` | `{ email, password, displayName }` | `{ token, user: { id, email, displayName } }` |
| POST | `/auth/login` | `{ emailOrUsername, password }` (either works; changed in Phase 3) | `{ token, user }` |
| GET | `/me` | | `{ id, email, displayName }` (checks a saved login on launch; added in Phase 3) |
| GET | `/sports` | | `[{ id, name }]` |
| GET | `/sports/{sportId}/categories` | | `[{ id, name, sportId }]` |
| GET | `/quiz?categoryId=&count=10` | | `{ sessionToken, questions: [{ id, text, options: [4 strings] }] }` |
| POST | `/quiz/answer` | `{ sessionToken, questionId, selectedIndex }` | `{ correct, correctIndex, score, answered, total }` (instant feedback; the answer is locked in; 409 if already answered; added in Phase 3) |
| POST | `/games` | `{ sessionToken }` (scored from the locked-in answers; changed in Phase 3) | `{ gameId, score, total, review: [{ questionId, correctIndex, selectedIndex, correct }] }` (`selectedIndex` is -1 if unanswered; 409 if already submitted) |
| GET | `/games/history` | | `[{ gameId, sportName, categoryName, score, total, playedAt }]` (`sportName` added in Phase 3) |
| GET | `/leaderboard?sportId=&top=20` | | `[{ rank, displayName, bestScore, gamesPlayed }]` |

Errors use a consistent shape: `{ error: "message" }` with correct status codes (400, 401, 404, 409 for duplicate email).

## Data model

- `Users` (Id, Email unique, PasswordHash, DisplayName, CreatedAt)
- `Sports` (Id, Name)
- `Categories` (Id, SportId FK, Name)
- `Questions` (Id, CategoryId FK, Text, Option1-4, CorrectIndex 0-3, Difficulty 1-3)
- `GameSessions` (Id, UserId FK, CategoryId FK, Score, Total, PlayedAt)

Leaderboard is a query over `GameSessions`, not a table. Add indexes on `Questions.CategoryId` and `GameSessions(UserId, CategoryId)`.

---

## Phase 0 — Scaffold (target: tonight)

- [ ] Create monorepo: `/api`, `/mobile`, `/seed`, root `README.md`, `DECISIONS.md`, `.gitignore`.
- [ ] `/api`: new ASP.NET Core Web API (.NET 8), add EF Core SqlServer, JWT bearer auth, Swagger with bearer support.
- [ ] `docker-compose.yml` with SQL Server 2022 for local dev (note: Apple Silicon needs the `mcr.microsoft.com/azure-sql-edge` image or `platform: linux/amd64` with Rosetta; pick what works on a MacBook Air and document it).
- [ ] `/mobile`: `flutter create` with packages: `dio`, `flutter_secure_storage`, `provider` (or `flutter_riverpod`), `go_router`.
- [ ] Run `flutter doctor` and fix or report any issues.

**Done when:** `dotnet run` serves Swagger, the DB container is up, and `flutter run` shows the default app in a simulator.

## Phase 1 — Backend core

- [ ] EF Core models, DbContext, and initial migration; apply it to the local DB.
- [ ] Auth: register/login, `PasswordHasher`, JWT generation (key, issuer, audience, expiry from config), email uniqueness, basic validation.
- [ ] Quiz endpoints: sports, categories, quiz (random N questions for a category, no answers in payload).
- [ ] `POST /games`: score server-side from the DB, save a `GameSession`, return the review.
- [ ] History and leaderboard endpoints.
- [ ] Global exception handling middleware with the error shape above, plus CORS config.
- [ ] Integration tests (xUnit + `WebApplicationFactory`, in-memory or test DB) covering: register, login, duplicate email, unauthorized access, quiz has no answers, scoring correctness, leaderboard ordering.

**Done when:** all tests pass and every endpoint works through Swagger.

## Phase 2 — Seed data (can run in parallel with Phase 3)

- [ ] Define the JSON format in `/seed/questions.schema.json`:
  ```json
  { "sport": "NFL", "category": "History", "text": "...", "options": ["a","b","c","d"], "correctIndex": 2, "difficulty": 2 }
  ```
- [ ] Generate about 100 questions per category as JSON files in `/seed` for Soccer (European Top 5 Leagues, Internationals) and NFL (History, Records and Stats, Players). Mix difficulties 1-3.
- [ ] Write a validation script: exactly 4 distinct options, `correctIndex` in range, no duplicate question text, no empty fields.
- [ ] Write an idempotent seed loader (runs on startup in Development, and via a CLI flag for prod).
- [x] Produce `seed/REVIEW.md` listing any question you are less than very confident about, so I can fact-check them.

**Done when:** validation passes and the DB contains the seeded questions.

## Phase 3 — Flutter app

Build against the API contract above. Keep the base URL in one config file with a switch for local/Android-emulator/prod.

- [ ] API client: `dio` with an interceptor that attaches the JWT and, on 401, clears the token and routes to login.
- [ ] Token storage with `flutter_secure_storage`; auto-login on launch if a token exists.
- [ ] Screens, in order: Login/Register, Sport picker, Category picker, Quiz (progress bar, one question at a time, 4 answer buttons), Results (score plus per-question review using the `review` array), Leaderboard (sport selector), History.
- [ ] Loading and error states on every network call. Friendly messages, no raw exceptions.
- [ ] Clean, consistent theme (one color scheme, readable typography). No animation work.
- [ ] Widget tests for the quiz screen logic and a couple of API-client tests with a mocked `dio`.

**Done when:** in the simulator I can register, play a full round, see results, and find myself on the leaderboard, all against the local API.

## Phase 4 — Deploy (stop for approval before creating resources)

- [ ] Write an `infra/deploy.md` (and optionally an `infra/deploy.sh` using `az` CLI) for: resource group, Azure SQL server and database (cheapest tier), App Service plan and web app.
- [ ] **Ask me before running anything that creates resources.** Then run `az login` handoff, and execute.
- [ ] Configure App Service settings: connection string, JWT key/issuer/audience. Enable HTTPS only.
- [ ] Apply migrations and seed to Azure SQL (add firewall rule for my IP).
- [ ] Add a GitHub Actions workflow that builds, tests, and deploys `/api` to App Service on push to `main`.
- [ ] Deploy a trivial health endpoint first (`GET /health`) to verify the pipeline before the full API.
- [ ] Point the Flutter prod base URL at the Azure URL and verify the full loop from the simulator.

**Done when:** the simulator plays a game against the Azure-hosted API.

## Phase 5 — Ship the MVP

- [ ] App icon and splash screen (use `flutter_launcher_icons` and `flutter_native_splash` with a simple placeholder logo).
- [ ] `flutter build apk --release`; document the install steps.
- [ ] README: architecture diagram (Mermaid), setup steps, API overview, screenshots section.
- [ ] Final pass: remove dead code, make sure no secrets are in git history, tag `v0.1.0`.

## Post-MVP backlog (do NOT start until I say so)

1. Account deletion endpoint and in-app button (required by both stores)
2. Privacy policy and terms pages
3. Refresh tokens, rate limiting on `/auth/*`, password reset by email
4. Always-on Azure tier, Key Vault, backups, Application Insights
5. Remaining 3 sports plus S3-hosted question images / team logos
6. Report-a-question flow, daily challenge, streaks, timers
7. Crash reporting, analytics, store listings (Apple $99/yr, Google Play $25 one-time; Play requires a 14-day closed test with about 12 testers for new accounts)

## Definition of done for the MVP

- [ ] A new user can register, log in, play a 10-question round, see a scored review, and appear on the leaderboard
- [ ] The API is live on Azure with Swagger, backed by seeded Azure SQL
- [ ] The Flutter app works against the live API in a simulator and as an Android APK
- [ ] Tests pass, README is accurate, and no secrets are committed
