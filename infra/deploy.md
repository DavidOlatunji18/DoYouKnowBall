# Deploying to Azure

The API runs on Azure App Service (Basic B1, always on, about $13 a month) and the database on Azure SQL (Basic, about $5 a month). Neither sleeps.

**Live API:** https://dykb-api-csbb.azurewebsites.net (health check at `/health`, docs at `/swagger`)

## What's running

| Resource | Name | Tier | Region |
|---|---|---|---|
| Resource group | `dykb-rg` | — | East US 2 (metadata only) |
| SQL server | `dykb-sql-csbb` | — | Central US |
| SQL database | `dykb` | Basic (5 DTUs, 2 GB max; about $5/month) | Central US |
| App Service plan | `dykb-plan` | B1 Basic, Linux, Always On (about $13/month) | Central US |
| Web app | `dykb-api-csbb` | .NET 10 | Central US |

**Tiers:** the database started on the free serverless offer, which paused after an hour idle; it moved to Basic (5 DTUs, 2 GB) in late October 2026 so it never pauses. The data is about 8 MB. The API's connection retries stay in place for brief outages.

**Why Central US:** East US 2 and East US weren't accepting new SQL servers for this subscription when it was set up, so everything went to the nearest region that was.

## Security and configuration

- **Secrets live in App Service settings, not in git.** The connection string is in `ConnectionStrings__Default` and the JWT signing key in `Jwt__Key`. Production has its own JWT key, separate from local development.
- **HTTPS only,** with TLS 1.2 minimum. Plain HTTP redirects to HTTPS, and FTP deploys are off.
- **The SQL firewall** allows Azure services (so the API can connect) and one developer IP (`DevMac`, for running migrations).
- **The SQL admin password** was generated randomly and is kept in a password manager.

To see or change the settings:

```bash
az webapp config appsettings list -g dykb-rg -n dykb-api-csbb -o table
```

## Automatic deploys (GitHub Actions)

Every push to `main` that changes `api/`, `seed/` or the workflow runs `.github/workflows/deploy-api.yml`:

1. Runs the API tests. A failing test stops the deploy.
2. Builds the API and signs in to Azure.
3. Lets the runner through the SQL firewall, applies migrations and syncs seed questions, then removes the firewall rule.
4. Deploys to App Service and checks `/health`.

It can also be run by hand from the repo's **Actions** tab (**Deploy API → Run workflow**).

**How it signs in:** OpenID Connect. An Azure identity, `dykb-github-deploy`, trusts only GitHub Actions runs from `main` of `DavidOlatunji18/DoYouKnowBall` and can only manage the `dykb-rg` resource group. No Azure password is stored in GitHub.

**GitHub secrets it uses:** `AZURE_CLIENT_ID`, `AZURE_TENANT_ID`, `AZURE_SUBSCRIPTION_ID` (identifiers, not passwords) and `DYKB_PROD_CONNECTION` (the database connection string, for migrations).

**One-time setup,** already done once; rerunning it is safe:

```bash
az login
gh auth login
sh infra/setup-github-deploy.sh
```

## Deploying an update by hand

```bash
az login                      # once per machine
sh infra/deploy.sh            # build, upload, check /health
```

If the update includes a database change (a new migration) or edited seed questions, run with `--seed`. It applies migrations and syncs the questions before uploading:

```bash
export DYKB_PROD_CONNECTION='Server=tcp:dykb-sql-csbb.database.windows.net,1433;Initial Catalog=dykb;User ID=dykbadmin;Password=<from your password manager>;Encrypt=True;TrustServerCertificate=False;Connection Timeout=60;'
sh infra/deploy.sh --seed
```

The seed sync is safe to run any number of times: it adds new questions, updates edited ones and removes deleted ones.

**If your IP changed** (new Wi-Fi, for example), `--seed` can't reach the database until you update the firewall rule:

```bash
az sql server firewall-rule update -g dykb-rg -s dykb-sql-csbb -n DevMac \
  --start-ip-address "$(curl -s https://api.ipify.org)" --end-ip-address "$(curl -s https://api.ipify.org)"
```

## Pointing the app at it

Release builds of the app use the live API automatically (`AppConfig.production` in `mobile/lib/config.dart`). Debug runs use the API on your computer. To play against Azure from the simulator:

```bash
cd mobile
flutter run --dart-define=API_BASE_URL=https://dykb-api-csbb.azurewebsites.net
```

## Useful commands

```bash
az webapp log tail -g dykb-rg -n dykb-api-csbb     # live API logs
az webapp restart -g dykb-rg -n dykb-api-csbb      # restart the API
az webapp stop -g dykb-rg -n dykb-api-csbb         # take it offline
```

**Going back to free:** the API with `az appservice plan update -g dykb-rg -n dykb-plan --sku F1`. The database can't return to the free offer in place; it would need a new free database and a copy of the data.

**Removing everything** (permanent, deletes all live accounts and scores):

```bash
az group delete -n dykb-rg
```

## How it was created

For reference, these are the commands that set it up. `<password>` and `<jwt key>` were generated randomly.

```bash
az provider register -n Microsoft.Web --wait
az provider register -n Microsoft.Sql --wait
az group create -n dykb-rg -l eastus2

az sql server create -g dykb-rg -n dykb-sql-csbb -l centralus -u dykbadmin -p '<password>' --minimal-tls-version 1.2
az sql server firewall-rule create -g dykb-rg -s dykb-sql-csbb -n AllowAzureServices --start-ip-address 0.0.0.0 --end-ip-address 0.0.0.0
az sql server firewall-rule create -g dykb-rg -s dykb-sql-csbb -n DevMac --start-ip-address <your ip> --end-ip-address <your ip>
az sql db create -g dykb-rg -s dykb-sql-csbb -n dykb --edition GeneralPurpose --compute-model Serverless \
  --family Gen5 --capacity 2 --use-free-limit --free-limit-exhaustion-behavior AutoPause --backup-storage-redundancy Local

az appservice plan create -g dykb-rg -n dykb-plan -l centralus --sku F1 --is-linux
az webapp create -g dykb-rg -p dykb-plan -n dykb-api-csbb --runtime "DOTNETCORE:10.0" --https-only true
az webapp config appsettings set -g dykb-rg -n dykb-api-csbb --settings \
  "ConnectionStrings__Default=<connection string>" "Jwt__Key=<jwt key>" ASPNETCORE_ENVIRONMENT=Production
az webapp config set -g dykb-rg -n dykb-api-csbb --min-tls-version 1.2 --ftps-state Disabled --startup-file "dotnet Dykb.Api.dll"

sh infra/deploy.sh --seed
```
