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
