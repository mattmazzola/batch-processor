# Batch Processor

1 Read values
2 Add Result

## Docker setup

```powershell
docker build -t batch-processor-node .
```

```powershell
$sharedResourceGroupName = "shared"
$sharedRgString = 'klgoyi'

Import-Module "C:/repos/shared-resources/pipelines/scripts/common.psm1" -Force

$sharedResourceNames = Get-ResourceNames $sharedResourceGroupName $sharedRgString

$envFilePath = $(Resolve-Path ".env").Path
$databaseUrl = Get-EnvVarFromFile -envFilePath $envFilePath -variableName 'DATABASE_URL'
$shadowDatabaseUrl = Get-EnvVarFromFile -envFilePath $envFilePath -variableName 'SHADOW_DATABASE_URL'
$storageConnectionString = $(az storage account show-connection-string -g $sharedResourceGroupName -n $sharedResourceNames.storageAccount --query "connectionString" -o tsv)

docker run -it `
    --rm `
    -e DATABASE_URL=$databaseUrl `
    -e SHADOW_DATABASE_URL=$shadowDatabaseUrl `
    -d STORAGE_CONNECTION_STRING=$storageConnectionString `
    processor-node
```

## Scaling

- <https://learn.microsoft.com/en-us/azure/container-apps/scale-app?pivots=azure-cli#example-2>

## Links

- <https://www.youtube.com/watch?v=z_QnOKVpbkA>
- <https://www.youtube.com/watch?v=RRJn63wzrfM>