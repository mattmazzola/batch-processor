# Batch Processor

# Container Apps + DAPR + KEDA

### Setup Context

```bash
az login
az account set -n "Matt Mazzola - Personal Projects Recovered"
az account show --query "name" -o tsv
az acr login --name sharedklgoyiacr
```

## What If Deployment

```pwsh
./scripts/deploy.ps1
```

## Deployment

```pwsh
./scripts/deploy.ps1 -WhatIf:$false
```
