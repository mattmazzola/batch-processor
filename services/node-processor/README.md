# Batch Processor

1 Read values
2 Add Result

## Docker setup

```powershell
docker build -t batch-processor-node-storage .
```

```powershell
$sharedResourceGroupName = "shared"
$sharedRgString = 'klgoyi'

Import-Module "C:/repos/shared-resources/pipelines/scripts/common.psm1" -Force

$sharedResourceNames = Get-ResourceNames $sharedResourceGroupName $sharedRgString

$envFilePath = $(Resolve-Path ".env").Path
$databaseUrl = Get-EnvVarFromFile -envFilePath $envFilePath -variableName 'DATABASE_URL'
$storageConnectionString = $(az storage account show-connection-string -g $sharedResourceGroupName -n $sharedResourceNames.storageAccount --query "connectionString" -o tsv)

docker run -it `
    --rm `
    -e DATABASE_URL=$databaseUrl `
    -e STORAGE_CONNECTION_STRING=$storageConnectionString `
    -e STORAGE_QUEUE_NAME="node-processor-queue" `
    batch-processor-node-storage
```

## Scaling

- <https://learn.microsoft.com/en-us/azure/container-apps/scale-app?pivots=azure-cli#example-2>

## Links

- <https://www.youtube.com/watch?v=z_QnOKVpbkA>
- <https://www.youtube.com/watch?v=RRJn63wzrfM>
