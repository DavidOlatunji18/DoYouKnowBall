# Decisions

Choices made where the plan was ambiguous, newest last.

## Phase 0

- **Local SQL Server image:** `mcr.microsoft.com/mssql/server:2022-latest` with `platform: linux/amd64` under Rosetta. The plan's alternative, `azure-sql-edge`, was retired by Microsoft in September 2025 and no longer gets updates.
- **SA password** lives in a git-ignored root `.env` file, which docker-compose reads automatically. Compose refuses to start if it's missing.
- **Flutter state management:** `provider` (simpler of the two options in the plan).
- **Flutter platforms:** iOS and Android only (no web/desktop folders).
- **Flutter bundle ID:** `com.doyouknowball.dykb`.
- **.NET 10 instead of .NET 8:** .NET 8 support ends November 10, 2026. .NET 10 is the current LTS (supported to November 2028) and runs on Azure App Service. Pinned via `api/global.json`.
- **API port 5050, not 5000:** macOS AirPlay Receiver listens on port 5000 and returns 403s. The API binds to `http://localhost:5050` (Android emulator: `http://10.0.2.2:5050`).
- **Swagger UI is on in every environment**, so the deployed API can be used through Swagger (an MVP requirement). It's at `/swagger`.
- **No HTTPS redirection in the app:** locally it's HTTP only; in prod, App Service "HTTPS Only" handles it.
- **Swashbuckle** for Swagger rather than the template's `Microsoft.AspNetCore.OpenApi`, since it serves the UI and the bearer "Authorize" button.
- **Dev secrets** (`Jwt:Key`, `ConnectionStrings:Default`) live in .NET user-secrets, outside the repo.
- **JWT lifetime:** 7 days (`Jwt:ExpiryMinutes` = 10080), because there are no refresh tokens in the MVP.
- **`GET /health`** added now (anonymous), not in Phase 4.
- **`System.Security.Cryptography.Pkcs` pinned to 10.0.13** to override a vulnerable 9.0.11 version that the SQL client pulls in.

## Phase 1

- **`sessionToken` is required in `POST /games`** (added to the contract). It's an encrypted, 1-hour token (ASP.NET Data Protection) recording the user, category and the exact question IDs that `/quiz` served. Submissions must answer exactly those questions once each, so players can't choose which questions to be scored on or submit with someone else's quiz. **Known gap:** a token can be submitted more than once within its hour. Blocking that needs a stored "used" flag, which can come later if needed.
- **Every question must be answered** (`selectedIndex` 0–3). There's no timer in the MVP, so there's no "skipped" value.
- **Quiz `count` is limited to 1–10.** The leaderboard compares raw best scores, so a bigger quiz would be an unfair advantage.
- **Leaderboard:** for each user, best score and number of games in that sport's categories. Sorted by best score, then games played (more is higher), then display name. Ties on best score share a rank (1, 1, 3). `top` is limited to 1–100.
- **History** returns the 50 most recent games, newest first.
- **Emails** are trimmed and lowercased before storing and comparing, so `Kobe@x.com` and `kobe@x.com` are one account. Display names are trimmed and must be 2–30 characters. Passwords must be 8–100 characters.
- **Login failures** return the same 401 message whether the email or the password is wrong, so the API doesn't reveal which emails have accounts.
- **Auth is required by default** (a fallback authorization policy). Only `/auth/*` and `/health` opt out.
- **Register and login return 200** with the auth response, not 201.
- **CORS** allows origins listed in `Cors:AllowedOrigins` (empty by default). The mobile app doesn't need CORS; it's there for a future web client.
- **Category deletes are blocked** while games reference the category, so players' history is never silently lost.
- **Timestamps are UTC**, and JSON timestamps end in `Z`.
- **Tests use the EF Core in-memory provider**, as the plan allows. I also ran every endpoint once against the real SQL Server to check that `NEWID()` ordering and the leaderboard `GROUP BY` translate correctly.

## Phase 2

- **Soccer replaces NBA** (your call). Soccer has two categories: **European Top 5 Leagues** (Premier League, La Liga, Serie A, Bundesliga, Ligue 1, plus the Champions League) and **Internationals** (World Cup, Euros, Copa América, Nations League, women's tournaments). The leagues aren't split into separate categories. That can be done later by moving questions into new files.
- **NFL categories:** History, Records and Stats, Players (the plan's examples).
- **Question count:** 524 (Soccer 108 + 117; NFL 96 + 102 + 101).
- **Accuracy over freshness:** I avoided totals that change every week, such as active players' career numbers. Time-sensitive questions are worded "as of 2025" or "through 2024-25". My knowledge stops at mid-2026, so nothing asks about 2025-26 season results. Questions I'm less than very confident about are listed in `seed/REVIEW.md`.
- **Seed layout:** one JSON array per category at `seed/<sport>/<category>.json`. Every item repeats its `sport` and `category`, matching the schema in the plan.
- **The loader syncs rather than just inserting.** Sports and categories are matched by name and questions by exact text within their category. New questions are added, edited ones are updated in place (same ID), and questions deleted from a file are removed from that category. Sports and categories are never deleted, because games reference them. Changing a question's text counts as removing the old question and adding a new one.
- **The loader validates before writing anything.** It applies the same rules as `seed/validate.py` and rejects the whole load if any file is bad.
- **When it runs:** on every startup in Development, which also applies migrations. In production, `dotnet Dykb.Api.dll --seed` applies migrations, syncs the questions, then exits.
- **Seed files ship with the API:** they're copied into the build and publish output (`seed/` next to the DLL), so App Service has them without a separate upload.
- **Each question's correct answer is shuffled into a random slot** when the file is generated, so there's no "it's always B" pattern. Options are not reshuffled for each quiz.

## Branding

- **Brand color:** `#05ff85`. Text and icons on the green are black (15.6:1 contrast). White on the green is only 1.3:1, so it's never used there.
- **Logo (for now):** a classic light bulb with glow rays, black on #05ff85, no text, in the Snapback Sports style. It's an original drawing, so no license or credit is needed. We may upgrade it later; the runner-up was a realistic head in profile with the bulb inside. The source is `design/make_logo.py`; its output is in `mobile/assets/branding/`, as SVG and 1024px PNG, both on green and transparent.
- **App icon and splash** are generated by `flutter_launcher_icons` and `flutter_native_splash` (dev dependencies, configured in `mobile/flutter_launcher_icons.yaml` and `mobile/flutter_native_splash.yaml`). The splash is the bulb centred on #05ff85 with "Do You Know Ball?" at the bottom. Native splash screens can't render live text, so the wordmark is an image (`splash-wordmark.png`). Android 12+ uses the system splash API, which shows the bulb inside a circle; the artwork is sized for that.
