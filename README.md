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

# Building Images

```bash
cd services/dotnet-processor && docker build -t batch-processor-dotnet . && cd -
cd services/node-processor && docker build -t batch-processor-node . && cd -
cd services/node-sb-processor && docker build -t batch-processor-node-sb . && cd -
cd services/python-processor && docker build -t batch-processor-python . && cd -
```
