# Azure Deployment

This directory holds the Azure deployment definition for the cloud services.

## What This Deploys

- Azure Container Apps environment + Log Analytics workspace
- Azure Container Registry (Basic SKU, ~$5/mo)
- `work-insights-ingest-api` Container App

The image is shared (both `work-insights-api` and `work-insights-report-runner` are
built), but only the ingest API is deployed as a Container App. The report runner
can be added later as a Container App Job.

## Prerequisites

- Azure CLI (`az`) installed and logged in (`az login`)
- Docker installed
- Bicep CLI (`az bicep install`)
- A Supabase project with:
  - `SUPABASE_URL` (project URL)
  - `SUPABASE_ANON_KEY` (anon/public key)
  - `WORK_INSIGHTS_DATABASE_URL` (database connection string)

## Quick Deploy

Use the deploy script:

```bash
# Create parameters.local.json from parameters.example.json with real values
cp infra/azure/parameters.example.json infra/azure/parameters.local.json
# Edit parameters.local.json with your Supabase secrets, then:
./infra/azure/deploy.sh -g my-resource-group -p infra/azure/parameters.local.json
```

The script will:
1. Create the resource group if it doesn't exist
2. Deploy all Azure resources via Bicep (ACR, Container Apps env, Log Analytics, ingest API)
3. Build the Docker image from `cloud/`
4. Push the image to ACR
5. Restart the Container App with the new image

## Manual Deployment

### 1. Deploy infrastructure

```bash
az deployment group create \
  -g <resource-group> \
  -f infra/azure/main.bicep \
  -p @infra/azure/parameters.local.json
```

### 2. Build and push the image

```bash
# Login to the deployed ACR (get the name from deployment outputs)
az acr login --name <acr-name>

# Build and push
docker build -t <acr-login-server>/work-insights:latest -f cloud/Dockerfile cloud
docker push <acr-login-server>/work-insights:latest
```

### 3. Update the Container App

```bash
az containerapp update \
  -g <resource-group> \
  -n work-insights-ingest-api \
  --image <acr-login-server>/work-insights:latest
```

## Secrets

Secrets stay out of git. Pass them as deployment-time parameter values.

Required parameters:

- `supabaseUrl`
- `supabaseAnonKey`
- `databaseUrl`
- `publicBaseUrl`

Create `infra/azure/parameters.local.json` from `parameters.example.json` and keep it
untracked (it is in `.gitignore`).

## Outputs

After deployment, note these outputs:

- `acrLoginServer` — use this for `docker build` and `docker push`
- `acrName` — use this for `az acr login`
- `ingestAppResourceName` — the Container App name
- `containerAppsEnvironmentName` — the Container Apps environment name
