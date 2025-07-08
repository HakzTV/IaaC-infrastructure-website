#!/bin/bash
set -e
shopt -s expand_aliases

# Load secrets from .env file
if [ -f .env ]; then
  export $(grep -v '^#' .env | xargs)
else
  echo "❌ .env file not found. Please create it with your secrets."
  exit 1
fi

if [ -z "$ADMIN_PASSWORD" ]; then
  echo "❌ ADMIN_PASSWORD not set in .env"
  exit 1
fi
echo "✅ Loaded .env"

RESOURCE_GROUP="esol-wordpress-prod"
LOCATION="uksouth"
DEPLOYMENT_NAME="esol-wordpress-deployment"
BICEP_FILE="./bicep/main.bicep"

APP_NAME="telvin-wordpress"
POSTGRESQL_SERVER_NAME="postgres-telvin"
CUSTOM_DOMAIN="telvinis.online"
TENANT_ID=$(az account show --query tenantId --output tsv)
KEYVAULT_NAME="esolvault$(date +%s | cut -c1-8)"
BACKUP_TIME="2025-07-09T01:00:00Z"

SSL_DEPLOYMENT_NAME="esol-ssl-binding"
SSL_BICEP_FILE="./bicep/sslBinding.bicep"
APP_SERVICE_PLAN_NAME="${APP_NAME}-plan"
SUBDOMAIN="www"

echo "✅ Creating resource group..."
az group create --name "$RESOURCE_GROUP" --location "$LOCATION"

# Generate parameter file without ddosProtectionPlanId
cat <<EOF > bicep-params.json
{
  "location": { "value": "$LOCATION" },
  "appName": { "value": "$APP_NAME" },
  "postgresqlServerName": { "value": "$POSTGRESQL_SERVER_NAME" },
  "adminPassword": { "value": "$ADMIN_PASSWORD" },
  "customDomain": { "value": "$CUSTOM_DOMAIN" },
  "tenantId": { "value": "$TENANT_ID" },
  "keyVaultName": { "value": "$KEYVAULT_NAME" },
  "backupStartTime": { "value": "$BACKUP_TIME" }
}
EOF

echo "🔍 Validating template..."
az deployment group validate \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$BICEP_FILE" \
  --parameters "@bicep-params.json"

echo "🚀 Deploying..."
az deployment group create \
  --name "$DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$BICEP_FILE" \
  --parameters "@bicep-params.json" \
  --debug 2>&1 | tee deployment-debug.log

echo "✅ Main deployment completed successfully!"

echo "⏳ Waiting 10 minutes for DNS propagation and certificate validation..."
sleep 600

cat <<EOF > ssl-params.json
{
  "appServiceName": { "value": "$APP_NAME" },
  "appServicePlanName": { "value": "$APP_SERVICE_PLAN_NAME" },
  "domainName": { "value": "$CUSTOM_DOMAIN" },
  "subdomain": { "value": "$SUBDOMAIN" },
  "location": { "value": "$LOCATION" }
}
EOF

echo "🔍 Validating SSL binding template..."
az deployment group validate \
  --name "$SSL_DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$SSL_BICEP_FILE" \
  --parameters "@ssl-params.json"

echo "🚀 Deploying SSL binding..."
az deployment group create \
  --name "$SSL_DEPLOYMENT_NAME" \
  --resource-group "$RESOURCE_GROUP" \
  --template-file "$SSL_BICEP_FILE" \
  --parameters "@ssl-params.json"

echo "✅ SSL binding deployment complete."
echo "🌐 Deployment completed successfully!"