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
