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

## Phase 3: app UI

- **Background color:** soft lavender `#ECEAF6` (your pick). It replaced cream, which looked too much like BALLRS. Lavender is opposite green on the color wheel, so the green pops while the screen stays calm. Cloud `#EEF0F3` and Sky `#E4EDF8` were the alternatives; switching is one line (`AppColors.background`). Green `#05ff85` is the accent (primary buttons). Text is ink `#121212`, and muted text is `#6B6A64`. These live in `mobile/lib/theme.dart`.
- **Font:** Montserrat (replaced DM Sans, which also felt too close to BALLRS). It's bundled in `mobile/assets/fonts/` with its SIL Open Font License (free for apps). It's a variable font, so weights are set through `appFont(size, weight: ...)` in `theme.dart`. The splash text is rendered in Montserrat too.
- **Buttons:** primary buttons are green with ink text and a 2px ink border, which matches the outlined ball icons.
- **Sport ball icons** (soccer, football, basketball, baseball, hockey puck) are original drawings, made by `design/make_ball_icons.py` and rendered to PNG by `design/render_assets.sh`.
- **Welcome screen motion:** the logo and headline fade up, the balls drop in one at a time with a bounce and then bob gently, and the tagline types itself out. The Sign up button and the "Already have an account? Log in" line don't animate (your call: too much motion otherwise). With the system's "Reduce Motion" setting on, everything appears immediately.
- **Navigation:** go_router. Sign up and Log in are placeholder screens until those designs arrive. The "logged in → Home" redirect comes with auth.
- **Sign up and Log in share one screen** (`AuthScreen`) with a sliding toggle, so switching between them animates in place. `/signup` and `/login` just open it in different modes. The style is "sticker": ink outlines with hard offset shadows. Buttons sink when pressed, and a focused field gets a green shadow. The headline has a green marker sweep, a ball (soccer for sign up, football for log in) spins in the corner, sign-up shows a live "8+ characters" check, and errors shake.
- **Client-side validation mirrors the API's rules** (display name 2–30, valid email, password 8+), so most mistakes are caught without a network call. The server's own `{ error }` message is shown for anything else, such as a duplicate email or a wrong password.
- **Session:** the JWT and user are saved with `flutter_secure_storage` (Keychain or Keystore). On launch the native splash stays up until the saved session is read, so returning players go straight to Home. A 401 from any non-auth endpoint signs the player out. The router redirects signed-out players to Welcome and signed-in players to Home.
- **Home is a placeholder** ("You're in, {name}." plus Log out) until the sport-picker design arrives.
- **API address:** `lib/config.dart`, which defaults to `http://localhost:5050` (iOS simulator) or `http://10.0.2.2:5050` (Android emulator). Override with `--dart-define=API_BASE_URL=...`. iOS allows HTTP to local addresses only (`NSAllowsLocalNetworking`). Android allows cleartext only to `10.0.2.2` and `localhost` (`network_security_config.xml`), so production must use HTTPS.

- **Usernames work like Instagram's.** The API's `displayName` field is now a username: 3-30 characters of lowercase letters, numbers, periods and underscores, with no period at the start or end and never two in a row. It's **unique** (409 "That username is taken.") and stored lowercase. The rules live in the API's `UsernameRules.cs` and the app's `username_rules.dart`. The app lowercases what you type and drops characters that aren't allowed, so most mistakes can't even be typed. Usernames show with an `@` ("You're in, @kobe."). The JSON field keeps the name `displayName`, so the API contract didn't change shape.
- **Animated splash:** the native launch screen can't animate, so the app shows its own copy of it (same bulb and text, in the same positions) with a comet-style spinner in between. The hand-off is invisible. While it spins, the app reads the saved login and calls the new **`GET /me`** endpoint. A valid login goes to Home with a refreshed username, and a 401 signs the player out and goes to Welcome. If the API can't be reached within 6 seconds, the saved login is kept rather than kicking an offline player out. The splash stays up at least 0.9s so the spinner never just flickers. With Reduce Motion on, the spinner is a still ring.
- **Password rules (sign-up only):** 8-100 characters; not one repeated character (`11111111`); not a simple run (`12345678`, `abcdefgh`); must not contain the username or the email's name part; not on the common-password list (`api/Dykb.Api/Resources/common-passwords.txt`, about 100 entries; the app's copy is checked against it by a test). This follows NIST guidance: block guessable passwords rather than require symbol and number mixes, so a long non-obvious all-number password is fine. The rules only apply when a password is created, so existing passwords keep working. The sign-up screen shows "8+ characters" and "Hard to guess" checks live, and the second one names the problem.
- **Login accepts email or username.** The request field is now `emailOrUsername` (was `email`). Anything with an `@` after the first character is treated as an email; otherwise it's a username, and a leading `@` is ignored, so `kobe24`, `@Kobe24` and `kobe@example.com` all work. The failure message is "Incorrect username, email or password.", which doesn't reveal which accounts exist.
- **Android launch screen:** Android 12+ forces the launch-screen text image into a fixed 800x320 box (our first, wider image got squashed), so Android has its own 800x320 version with the same text size. The bulb shows at 288dp, the size Android 12+ uses for launch icons, on every Android version. Measured on the emulator, the app's own splash places the bulb and text within 2px of the native screen, so the hand-off doesn't jump. The app releases the native launch screen as soon as its own splash is built: waiting for a frame first can deadlock, because the native screen holds Flutter's first frame back.
