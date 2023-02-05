$sharedResourceGroupName = "shared"
$sharedRgString = 'klgoyi'
$resourceGroupLocation = "westus3"
$batchProcessorResourceGroupName = "batch-processor"

echo "PScriptRoot: $PScriptRoot"
$repoRoot = If ('' -eq $PScriptRoot) {
  "$PSScriptRoot/.."
}
else {
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
$shadowDatabaseConnectionString = Get-EnvVarFromFile -envFilePath $envFilePath -variableName 'SHADOW_DATABASE_URL'
$storageConnectionString = $(az storage account show-connection-string -g $sharedResourceGroupName -n $sharedResourceNames.storageAccount --query "connectionString" -o tsv)
$storageQueueName = $(az storage queue list --connection-string $storageConnectionString --query "[].name" -o tsv)

Write-Step "Fetch params from Azure"
$sharedResourceVars = Get-SharedResourceDeploymentVars $sharedResourceGroupName $sharedRgString

$nodeProcessorContainerName = "$batchProcessorResourceGroupName-node"
$nodeProcessorImageTag = $(Get-Date -Format "yyyyMMddhhmm")
$nodeProcessorImageName = "$($sharedResourceVars.registryUrl)/${nodeProcessorContainerName}:${nodeProcessorImageTag}"

$clientContainerName = "$batchProcessorResourceGroupName-client"
$clientImageTag = $(Get-Date -Format "yyyyMMddhhmm")
$clientImageName = "$($sharedResourceVars.registryUrl)/${clientContainerName}:${clientImageTag}"

$data = [ordered]@{
  "databaseConnectionString"       = "$($databaseConnectionString.Substring(0, 15))..."
  "shadowDatabaseConnectionString" = "$($shadowDatabaseConnectionString.Substring(0, 15))..."
  "storageConnectionString"        = "$($storageConnectionString.Substring(0, 15))..."
  "storageQueueName"               = $storageQueueName

  "nodeProcessorImageName"         = $nodeProcessorImageName
  "clientImageName"                = $clientImageName

  "containerAppsEnvResourceId"     = $($sharedResourceVars.containerAppsEnvResourceId)
  "registryUrl"                    = $($sharedResourceVars.registryUrl)
  "registryUsername"               = $($sharedResourceVars.registryUsername)
  "registryPassword"               = "$($($sharedResourceVars.registryPassword).Substring(0, 5))..."
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
docker build -t $nodeProcessorImageName "$repoRoot/services/processor"
docker push $nodeProcessorImageName
# TODO: Investigate why using 'az acr build' does not work
# az acr build -r $registryUrl -t $nodeProcessorImageName ./services/processor

Write-Step "Deploy $nodeProcessorImageName Container App"
$nodeProcessorBicepContainerDeploymentFilePath = "$repoRoot/bicep/modules/nodeProcessorContainerApp.bicep"
# az deployment group create `
#     -g $batchProcessorResourceGroupName `
#     -f $nodeProcessorBicepContainerDeploymentFilePath `
#     -p managedEnvironmentResourceId=$($sharedResourceVars.containerAppsEnvResourceId) `
#     registryUrl=$($sharedResourceVars.registryUrl) `
#     registryUsername=$($sharedResourceVars.registryUsername) `
#     registryPassword=$($sharedResourceVars.registryPassword) `
#     imageName=$nodeProcessorImageName `
#     containerName=$nodeProcessorContainerName `
#     queueName=$($sharedResourceNames.storageQueue) `
#     storageAccountName=$($sharedResourceNames.storageAccount) `
#     storageConnectionString=$storageConnectionString `
#     databaseConnectionString=$databaseConnectionString `
#     shadowDatabaseConnectionString=$shadowDatabaseConnectionString `
#     --what-if

az deployment group create `
  -g $batchProcessorResourceGroupName `
  -f $nodeProcessorBicepContainerDeploymentFilePath `
  -p managedEnvironmentResourceId=$($sharedResourceVars.containerAppsEnvResourceId) `
  registryUrl=$($sharedResourceVars.registryUrl) `
  registryUsername=$($sharedResourceVars.registryUsername) `
  registryPassword=$($sharedResourceVars.registryPassword) `
  imageName=$nodeProcessorImageName `
  containerName=$nodeProcessorContainerName `
  queueName=$($sharedResourceNames.storageQueue) `
  storageAccountName=$($sharedResourceNames.storageAccount) `
  storageConnectionString=$storageConnectionString `
  databaseConnectionString=$databaseConnectionString `
  shadowDatabaseConnectionString=$shadowDatabaseConnectionString `
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
    queueName=$($sharedResourceNames.storageQueue) `
    storageConnectionString=$storageConnectionString `
    databaseConnectionString=$databaseConnectionString `
    shadowDatabaseConnectionString=$shadowDatabaseConnectionString `
    --query "properties.outputs.fqdn.value" `
    -o tsv)

$clientUrl = "https://$clientFqdn"
Write-Output $clientUrl
