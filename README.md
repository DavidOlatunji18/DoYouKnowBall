# Do You Know Ball?

A cross-platform sports trivia app: Flutter client, ASP.NET Core API, SQL Server. See [PLAN.md](PLAN.md) for the build plan and [DECISIONS.md](DECISIONS.md) for choices made along the way.

## Repo layout

| Folder | What's in it |
|---|---|
| `api/` | ASP.NET Core Web API |
| `mobile/` | Flutter app (iOS + Android) |
| `seed/` | Trivia question JSON and tooling |

## Prerequisites

- Docker Desktop, with **Settings > General > "Use Rosetta for x86_64/amd64 emulation"** turned on (Apple Silicon only)
- .NET SDK
- Flutter 3.38+ and Xcode (iOS) / Android Studio (Android)

## Running locally

### 1. Database

Create a `.env` file in the repo root (it's git-ignored) with a strong SA password:

```bash
echo "MSSQL_SA_PASSWORD=<at least 8 chars, upper, lower, digit, symbol>" > .env
docker compose up -d
docker compose ps        # wait for "healthy"
```

SQL Server is then on `localhost,1433` (user `sa`). Stop it with `docker compose down`; data persists in the `sqldata` volume.

### 2. API

Requires the .NET 10 SDK (pinned in `api/global.json`). First-time setup stores dev secrets outside the repo:

```bash
cd api/Dykb.Api
dotnet user-secrets set "Jwt:Key" "$(openssl rand -base64 48)"
dotnet user-secrets set "ConnectionStrings:Default" \
  "Server=localhost,1433;Database=Dykb;User Id=sa;Password=<your MSSQL_SA_PASSWORD>;TrustServerCertificate=True"
```

Create the database tables (and re-run after pulling new migrations):

```bash
cd api
dotnet tool restore
dotnet ef database update --project Dykb.Api
```

Then run it:

```bash
cd api/Dykb.Api
dotnet run
```

Run the integration tests (they use an in-memory database, so neither Docker nor user-secrets are needed):

```bash
cd api
dotnet test
```

### Trying the API in Swagger

1. `POST /auth/register` with an email, password (8+ chars) and display name.
2. Copy the `token` from the response, click **Authorize**, and paste it in.
3. `GET /sports` → `GET /sports/{id}/categories` → `GET /quiz?categoryId=…`
4. `POST /games` with the `categoryId`, the `sessionToken` from the quiz, and one answer per question.
5. `GET /games/history` and `GET /leaderboard?sportId=…`

The database has no questions until Phase 2 adds the seed loader.

| Endpoint | Auth | Notes |
|---|---|---|
| `POST /auth/register`, `POST /auth/login` | — | 409 on duplicate email, 401 on bad login |
| `GET /sports`, `GET /sports/{id}/categories` | JWT | |
| `GET /quiz?categoryId=&count=10` | JWT | Up to 10 random questions, no answers |
| `POST /games` | JWT | Scored on the server; needs the quiz's `sessionToken` |
| `GET /games/history` | JWT | Your 50 most recent games |
| `GET /leaderboard?sportId=&top=20` | JWT | Best score per player in that sport |
| `GET /health` | — | |

Errors always look like `{ "error": "message" }`.

- Swagger: http://localhost:5050/swagger
- Health check: http://localhost:5050/health
- Android emulator reaches it at `http://10.0.2.2:5050`

The port is 5050 because macOS AirPlay Receiver uses 5000. EF Core CLI is a local tool: run `dotnet tool restore` once in `api/`, then `dotnet ef ...`.

### 3. Mobile

```bash
cd mobile
open -a Simulator        # or start an Android emulator
flutter run
```
