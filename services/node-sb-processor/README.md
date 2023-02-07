# Node Service Bus Processor

## Docker setup

```powershell
docker build -t batch-processor-node-sb .
```

```powershell
$sharedResourceGroupName = "shared"
$sharedRgString = 'klgoyi'

Import-Module "C:/repos/shared-resources/pipelines/scripts/common.psm1" -Force

$sharedResourceNames = Get-ResourceNames $sharedResourceGroupName $sharedRgString

$envFilePath = $(Resolve-Path ".env").Path
$databaseConnectionString = Get-EnvVarFromFile -envFilePath $envFilePath -variableName 'DATABASE_URL'
$serviceBusNamespaceConnectionString = $(az servicebus namespace authorization-rule keys list -g $sharedResourceGroupName --namespace-name $sharedResourceNames.servicebus -n 'RootManageSharedAccessKey' --query 'primaryConnectionString' -o tsv)
$serviceBusQueueName = $(az servicebus queue list -g $sharedResourceGroupName --namespace-name $sharedResourceNames.servicebus --query '[0].name' -o tsv)

docker run -it `
    --rm `
    -e DATABASE_URL=$databaseConnectionString `
    -e SERVICE_BUS_NAMESPACE_CONNECTION_STRING=$serviceBusNamespaceConnectionString `
    -e SERVICE_BUS_NODE_QUEUE_NAME="node-sb-processor-queue" `
    batch-processor-node-sb
```

## Resources

- <https://github.com/Azure/azure-sdk-for-js/tree/main/sdk/servicebus/service-bus#receive-messages>
