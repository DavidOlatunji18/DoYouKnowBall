#!/usr/bin/env bash
# Builds the API and deploys it to Azure App Service.
#   sh infra/deploy.sh          # deploy the code
#   sh infra/deploy.sh --seed   # also apply migrations and sync seed questions first
#
# Needs: the Azure CLI, logged in with `az login`. --seed also needs the database
# connection string in DYKB_PROD_CONNECTION (see infra/deploy.md) and your current
# IP allowed through the SQL firewall.
set -euo pipefail

RG=dykb-rg
APP=dykb-api-csbb
ROOT="$(cd "$(dirname "$0")/.." && pwd)"
OUT="$(mktemp -d)"
trap 'rm -rf "$OUT"' EXIT

echo "Building the API..."
dotnet publish "$ROOT/api/Dykb.Api" -c Release -o "$OUT/publish" --nologo -v quiet

if [[ "${1:-}" == "--seed" ]]; then
  : "${DYKB_PROD_CONNECTION:?Set DYKB_PROD_CONNECTION to the Azure SQL connection string}"
  echo "Applying migrations and syncing seed questions..."
  # The JWT key isn't used when seeding, but the API refuses to start without one.
  (cd "$OUT/publish" && ConnectionStrings__Default="$DYKB_PROD_CONNECTION" \
    Jwt__Key="$(openssl rand -base64 48)" ASPNETCORE_ENVIRONMENT=Production \
    dotnet Dykb.Api.dll --seed --Logging:LogLevel:Microsoft.EntityFrameworkCore=Warning)
fi

echo "Uploading..."
(cd "$OUT/publish" && zip -qr "$OUT/api.zip" .)
az webapp deploy -g "$RG" -n "$APP" --src-path "$OUT/api.zip" --type zip --only-show-errors -o none

echo "Checking health..."
curl -sf --retry 10 --retry-delay 6 --retry-all-errors "https://$APP.azurewebsites.net/health" && echo
echo "Deployed: https://$APP.azurewebsites.net"
