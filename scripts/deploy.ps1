$sharedResourceGroupName = "shared"
$sharedRgString = 'klgoyi'
$resourceGroupLocation = "westus3"
$batchProcessorResourceGroupName = "batch-processor"

echo "PScriptRoot: $PScriptRoot"
$repoRoot = If ('' -eq $PScriptRoot) {
  "$PSScriptRoot/.."
} Else {
  "."
}

echo "Repo Root: $repoRoot"

Import-Module "C:/repos/shared-resources/pipelines/scripts/common.psm1" -Force

$sharedResourceNames = Get-ResourceNames $sharedResourceGroupName $sharedRgString

Write-Step "Create Resource Group: $batchProcessorResourceGroupName"
az group create -l $resourceGroupLocation -g $batchProcessorResourceGroupName --query name -o tsv

$envFilePath = $(Resolve-Path "$repoRoot/scripts/.env").Path

Write-Step "Get ENV Vars from $envFilePath"
$databaseConnectionString = Get-EnvVarFromFile -envFilePath $envFilePath -variableName 'DATABASE_URL'
$storageConnectionString = $(az storage account show-connection-string -g $sharedResourceGroupName -n $sharedResourceNames.storageAccount --query "connectionString" -o tsv)
$nodeStorageQueueName = $(az storage queue list --connection-string $storageConnectionString --query "[0].name" -o tsv)
$pythonStorageQueueName = $(az storage queue list --connection-string $storageConnectionString --query "[1].name" -o tsv)
$serviceBusNamespaceConnectionString = $(az servicebus namespace authorization-rule keys list -g $sharedResourceGroupName --namespace-name $sharedResourceNames.servicebus -n 'RootManageSharedAccessKey' --query 'primaryConnectionString' -o tsv)
$serviceBusQueueName = $(az servicebus queue list -g $sharedResourceGroupName --namespace-name $sharedResourceNames.servicebus --query '[0].name' -o tsv)

Write-Step "Fetch params from Azure"
$sharedResourceVars = Get-SharedResourceDeploymentVars $sharedResourceGroupName $sharedRgString

$nodeProcessorContainerName = "$batchProcessorResourceGroupName-node"
$nodeProcessorImageTag = $(Get-Date -Format "yyyyMMddhhmm")
$nodeProcessorImageName = "$($sharedResourceVars.registryUrl)/${nodeProcessorContainerName}:${nodeProcessorImageTag}"

$nodeSbProcessorContainerName = "$batchProcessorResourceGroupName-sb-node"
$nodeSbProcessorImageTag = $(Get-Date -Format "yyyyMMddhhmm")
$nodeSbProcessorImageName = "$($sharedResourceVars.registryUrl)/${nodeSbProcessorContainerName}:${nodeSbProcessorImageTag}"

$pythonProcessorContainerName = "$batchProcessorResourceGroupName-python"
$pythonProcessorImageTag = $(Get-Date -Format "yyyyMMddhhmm")
$pythonProcessorImageName = "$($sharedResourceVars.registryUrl)/${pythonProcessorContainerName}:${pythonProcessorImageTag}"

$clientContainerName = "$batchProcessorResourceGroupName-client"
$clientImageTag = $(Get-Date -Format "yyyyMMddhhmm")
$clientImageName = "$($sharedResourceVars.registryUrl)/${clientContainerName}:${clientImageTag}"

$data = [ordered]@{
  "databaseConnectionString"            = "$($databaseConnectionString.Substring(0, 15))..."
  "storageConnectionString"             = "$($storageConnectionString.Substring(0, 15))..."
  "nodeStorageQueueName"                = $nodeStorageQueueName
  "pythonStorageQueueName"              = $pythonStorageQueueName
  "serviceBusNamespaceConnectionString" = "$($serviceBusNamespaceConnectionString.Substring(0, 15))..."
  "serviceBusQueueName"                 = $serviceBusQueueName

  "nodeProcessorImageName"              = $nodeProcessorImageName
  "nodeSbProcessorImageName"            = $nodeSbProcessorImageName
  "pythonProcessorImageName"            = $pythonProcessorImageName
  "clientImageName"                     = $clientImageName

  "containerAppsEnvResourceId"          = $($sharedResourceVars.containerAppsEnvResourceId)
  "registryUrl"                         = $($sharedResourceVars.registryUrl)
  "registryUsername"                    = $($sharedResourceVars.registryUsername)
  "registryPassword"                    = "$($($sharedResourceVars.registryPassword).Substring(0, 5))..."
}

Write-Hash "Data" $data

Write-Step "Provision Additional $sharedResourceGroupName Resources"
$mainBicepFile = "$repoRoot/bicep/main.bicep"
az deployment group create `
  -g $sharedResourceGroupName `
  -f $mainBicepFile `
  --query "properties.provisioningState" `
  -o tsv

Write-Step "Provision $batchProcessorResourceGroupName Resources"

Write-Step "Build and Push $nodeProcessorImageName Image"
docker build -t $nodeProcessorImageName "$repoRoot/services/node-processor"
docker push $nodeProcessorImageName
# TODO: Investigate why using 'az acr build' does not work
# az acr build -r $registryUrl -t $nodeProcessorImageName ./services/node-processor

Write-Step "Deploy $nodeProcessorImageName Container App"
$nodeProcessorBicepContainerDeploymentFilePath = "$repoRoot/bicep/modules/nodeProcessorContainerApp.bicep"

az deployment group create `
  -g $batchProcessorResourceGroupName `
  -f $nodeProcessorBicepContainerDeploymentFilePath `
  -p managedEnvironmentResourceId=$($sharedResourceVars.containerAppsEnvResourceId) `
  registryUrl=$($sharedResourceVars.registryUrl) `
  registryUsername=$($sharedResourceVars.registryUsername) `
  registryPassword=$($sharedResourceVars.registryPassword) `
  imageName=$nodeProcessorImageName `
  containerName=$nodeProcessorContainerName `
  queueName=$nodeStorageQueueName `
  storageAccountName=$($sharedResourceNames.storageAccount) `
  storageConnectionString=$storageConnectionString `
  databaseConnectionString=$databaseConnectionString `
  --query "properties.provisioningState" `
  -o tsv

Write-Step "Build and Push $nodeSbProcessorImageName Image"
docker build -t $nodeSbProcessorImageName "$repoRoot/services/node-sb-processor"
docker push $nodeSbProcessorImageName
# TODO: Investigate why using 'az acr build' does not work
# az acr build -r $registryUrl -t $nodeProcessorImageName ./services/node-processor

Write-Step "Deploy $nodeSbProcessorImageName Container App"
$nodeSbProcessorBicepContainerDeploymentFilePath = "$repoRoot/bicep/modules/nodeServiceBusProcessorContainerApp.bicep"

az deployment group create `
  -g $batchProcessorResourceGroupName `
  -f $nodeSbProcessorBicepContainerDeploymentFilePath `
  -p managedEnvironmentResourceId=$($sharedResourceVars.containerAppsEnvResourceId) `
  registryUrl=$($sharedResourceVars.registryUrl) `
  registryUsername=$($sharedResourceVars.registryUsername) `
  registryPassword=$($sharedResourceVars.registryPassword) `
  imageName=$nodeSbProcessorImageName `
  containerName=$nodeSbProcessorContainerName `
  queueName=$serviceBusQueueName `
  serviceBusNamespaceName=$($sharedResourceNames.serviceBus) `
  serviceBusConnectionString=$serviceBusNamespaceConnectionString `
  databaseConnectionString=$databaseConnectionString `
  --query "properties.provisioningState" `
  -o tsv

Write-Step "Build and Push $pythonProcessorImageName Image"
docker build -t $pythonProcessorImageName "$repoRoot/services/python-processor"
docker push $pythonProcessorImageName
# TODO: Investigate why using 'az acr build' does not work
# az acr build -r $registryUrl -t $pythonProcessorImageName ./services/python-processor

Write-Step "Deploy $pythonProcessorImageName Container App"
$pythonProcessorBicepContainerDeploymentFilePath = "$repoRoot/bicep/modules/pythonProcessorContainerApp.bicep"

az deployment group create `
  -g $batchProcessorResourceGroupName `
  -f $pythonProcessorBicepContainerDeploymentFilePath `
  -p managedEnvironmentResourceId=$($sharedResourceVars.containerAppsEnvResourceId) `
  registryUrl=$($sharedResourceVars.registryUrl) `
  registryUsername=$($sharedResourceVars.registryUsername) `
  registryPassword=$($sharedResourceVars.registryPassword) `
  imageName=$pythonProcessorImageName `
  containerName=$pythonProcessorContainerName `
  queueName=$pythonStorageQueueName `
  storageAccountName=$($sharedResourceNames.storageAccount) `
  storageConnectionString=$storageConnectionString `
  databaseConnectionString=$databaseConnectionString `
  --query "properties.provisioningState" `
  -o tsv

Write-Step "Build and Push $clientImageName Image"
docker build -t $clientImageName "$repoRoot/apps/website"
docker push $clientImageName

# az acr build -r $registryUrl -t $clientImageName "$repoRoot/apps/website"

Write-Step "Deploy $clientImageName Container App"
$clientBicepContainerDeploymentFilePath = "$repoRoot/bicep/modules/clientContainerApp.bicep"
$clientFqdn = $(az deployment group create `
    -g $batchProcessorResourceGroupName `
    -f $clientBicepContainerDeploymentFilePath `
    -p managedEnvironmentResourceId=$($sharedResourceVars.containerAppsEnvResourceId) `
    registryUrl=$($sharedResourceVars.registryUrl) `
    registryUsername=$($sharedResourceVars.registryUsername) `
    registryPassword=$($sharedResourceVars.registryPassword) `
    imageName=$clientImageName `
    containerName=$clientContainerName `
    nodeQueueName=$nodeStorageQueueName `
    pythonQueueName=$pythonStorageQueueName `
    storageConnectionString=$storageConnectionString `
    databaseConnectionString=$databaseConnectionString `
    serviceBusConnectionString=$serviceBusNamespaceConnectionString `
    serviceBusQueueName=$serviceBusQueueName `
    --query "properties.outputs.fqdn.value" `
    -o tsv)

$clientUrl = "https://$clientFqdn"
Write-Output $clientUrl
