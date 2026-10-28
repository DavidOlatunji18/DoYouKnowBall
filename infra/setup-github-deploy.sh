#!/usr/bin/env bash
# One-time setup so GitHub Actions can deploy the API (.github/workflows/deploy-api.yml).
#
# Creates an Azure identity, "dykb-github-deploy", that:
#   - only trusts GitHub Actions runs from the main branch of this repo (OpenID
#     Connect, so no Azure password is stored anywhere), and
#   - can only manage the dykb-rg resource group.
# Then saves the values the workflow needs as GitHub secrets.
#
# Needs: `az login` and `gh auth login` done first. Run from the repo root:
#   sh infra/setup-github-deploy.sh
set -euo pipefail

REPO=DavidOlatunji18/DoYouKnowBall
RG=dykb-rg
NAME=dykb-github-deploy

SUBSCRIPTION_ID=$(az account show --query id -o tsv)
TENANT_ID=$(az account show --query tenantId -o tsv)
RG_ID=$(az group show -n "$RG" --query id -o tsv)

echo "Creating the deploy identity..."
CLIENT_ID=$(az ad app list --display-name "$NAME" --query "[0].appId" -o tsv)
if [[ -z "$CLIENT_ID" ]]; then
  CLIENT_ID=$(az ad app create --display-name "$NAME" --query appId -o tsv)
fi
az ad sp show --id "$CLIENT_ID" -o none 2>/dev/null || az ad sp create --id "$CLIENT_ID" -o none

echo "Trusting GitHub Actions on $REPO (main branch only)..."
if [[ -z "$(az ad app federated-credential list --id "$CLIENT_ID" --query "[?name=='github-main'].name" -o tsv)" ]]; then
  az ad app federated-credential create --id "$CLIENT_ID" -o none --parameters "{
    \"name\": \"github-main\",
    \"issuer\": \"https://token.actions.githubusercontent.com\",
    \"subject\": \"repo:$REPO:ref:refs/heads/main\",
    \"audiences\": [\"api://AzureADTokenExchange\"]
  }"
fi

echo "Allowing it to manage $RG only..."
# A brand-new identity can take a few seconds to be visible to role assignments.
for attempt in 1 2 3 4 5 6; do
  if az role assignment create --assignee "$CLIENT_ID" --role Contributor --scope "$RG_ID" -o none 2>/dev/null; then
    break
  fi
  if [[ $attempt == 6 ]]; then echo "Couldn't assign the role; try running this script again."; exit 1; fi
  sleep 10
done

echo "Saving GitHub secrets..."
gh secret set AZURE_CLIENT_ID --repo "$REPO" --body "$CLIENT_ID"
gh secret set AZURE_TENANT_ID --repo "$REPO" --body "$TENANT_ID"
gh secret set AZURE_SUBSCRIPTION_ID --repo "$REPO" --body "$SUBSCRIPTION_ID"

echo
echo "Last one: the database connection string, so deploys can run migrations."
echo "Copy it from the Azure portal: web app dykb-api-csbb > Environment variables >"
echo "ConnectionStrings__Default > Show value. Paste it below (it won't be shown):"
gh secret set DYKB_PROD_CONNECTION --repo "$REPO"

echo
echo "Done. Every push to main that changes api/ or seed/ now tests and deploys the API."
