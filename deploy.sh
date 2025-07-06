#!/bin/bash
set -e

# 💡 Safe Bash Settings
shopt -s expand_aliases

# ✅ Deployment Configuration
ADMIN_PASSWORD="My$uper$trongP@ssw0rd!"
RESOURCE_GROUP="esol-website-prod"
LOCATION="uksouth"
DEPLOYMENT_NAME="esol-wordpress-deployment"
BICEP_FILE="./bicep/main.bicep"

APP_NAME="telvin-wordpress"
POSTGRESQL_SERVER_NAME="postgres-telvin"
FRONTDOOR_NAME="telvin-frontdoor"
CUSTOM_DOMAIN="telvinis.online"
TENANT_ID=$(az account show --query tenantId --output tsv)
KEYVAULT_NAME="esolvault$(date +%s | cut -c1-8)"
BACKUP_TIME="2025-07-04T01:00:00Z"
DDOS_PLAN_NAME="wp-ddos-plan"

# ✅ Create Resource Group
echo "✅ Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# ✅ Get or Create DDoS Protection Plan
echo "🔍 Checking for existing DDoS plan..."
DDOS_PLAN_ID=$(az network ddos-protection list \
  --query "[?location=='$LOCATION'].id" \
  --output tsv)

if [ -z "$DDOS_PLAN_ID" ]; then
  echo "🛠️  Creating new DDoS plan..."
  az network ddos-protection create \
    --resource-group "$RESOURCE_GROUP" \
    --name "$DDOS_PLAN_NAME" \
    --location "$LOCATION"
  DDOS_PLAN_ID=$(az network ddos-protection show \
    --name "$DDOS_PLAN_NAME" \
    --resource-group "$RESOURCE_GROUP" \
    --query id --output tsv)
fi

# ✅ Strip Git Bash Rewriting if Present
# Example: C:/Program Files/Git/subscriptions/... ➜ /subscriptions/...
DDOS_PLAN_ID=$(echo "$DDOS_PLAN_ID" | sed -E 's|^[A-Za-z]:/.*(/subscriptions)|\1|')
DDOS_PLAN_ID=$(echo "$DDOS_PLAN_ID" | sed -E 's|^/c/Program Files/Git||I')

# ✅ Final Check
if [[ "$DDOS_PLAN_ID" != /subscriptions/* ]]; then
  echo "❌ INVALID DDoS Plan ID: $DDOS_PLAN_ID"
  exit 1
fi
echo "🧼 Clean DDoS Plan ID: $DDOS_PLAN_ID"

# ✅ Generate Parameter File

cat <<EOF > bicep-params.json
{
  "location": { "value": "$LOCATION" },
  "appName": { "value": "$APP_NAME" },
  "postgresqlServerName": { "value": "$POSTGRESQL_SERVER_NAME" },
  "adminPassword": { "value": "$ADMIN_PASSWORD" },
  "frontdoorName": { "value": "$FRONTDOOR_NAME" },
  "customDomain": { "value": "$CUSTOM_DOMAIN" },
  "ddosProtectionPlanId": { "value": "$DDOS_PLAN_ID" },
  "tenantId": { "value": "$TENANT_ID" },
  "keyVaultName": { "value": "$KEYVAULT_NAME" },
  "backupStartTime": { "value": "$BACKUP_TIME" }
}
EOF

# ✅ Validate Deployment
echo "🔍 Validating template..."
az deployment group validate \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$BICEP_FILE" \
  --parameters "@bicep-params.json"

# ✅ Deploy to Azure
echo "🚀 Deploying..."
az deployment group create \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$BICEP_FILE" \
  --parameters "@bicep-params.json" \
  --debug 2>&1 | tee deployment-debug.log

echo "✅ DONE"
