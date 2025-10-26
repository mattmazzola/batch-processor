Param([switch]$WhatIf = $True)

$scriptPath = $MyInvocation.MyCommand.Path
$scriptDir = Split-Path $scriptPath

# Find repo root by searching upward for README.md
$currentDir = $scriptDir
$repoRoot = $null
while ($currentDir -and -not $repoRoot) {
  if (Test-Path (Join-Path $currentDir "README.md")) {
    $repoRoot = $currentDir
  }
  else {
    $currentDir = Split-Path $currentDir
  }
}
if (-not $repoRoot) {
  throw "Could not find repo root (no README.md found in parent directories)."
}

echo "Script Path: $scriptPath"
echo "Script Dir: $scriptDir"
echo "Repo Root: $repoRoot"

$sharedModulePath = Resolve-Path "$repoRoot/../shared-resources/pipelines/scripts/common.psm1"
$localModulePath = Resolve-Path "$repoRoot/scripts/common.psm1"

echo "Shared Module Path: $sharedModulePath"
echo "Local Module Path: $localModulePath"

Import-Module $sharedModulePath -Force
Import-Module $localModulePath -Force

$inputs = @{
  "WhatIf" = $WhatIf
}

Write-Hash "Inputs" $inputs

$sharedResourceGroupName = "shared"
$sharedRgString = 'klgoyi'
$resourceGroupLocation = "westus3"
$batchProcessorResourceGroupName = "batch-processor"

$sharedResourceNames = Get-ResourceNames $sharedResourceGroupName $sharedRgString
$batchProcessorResourceNames = Get-LocalResourceNames $batchProcessorResourceGroupName 'unused'

Write-Step "Create Resource Group: $batchProcessorResourceGroupName"
az group create -l $resourceGroupLocation -g $batchProcessorResourceGroupName --query name -o tsv

$envFilePath = $(Resolve-Path "$repoRoot/scripts/.env").Path

Write-Step "Get ENV Vars from $envFilePath"
$databaseConnectionString = Get-EnvVarFromFile -envFilePath $envFilePath -variableName 'DATABASE_URL'

Write-Step "Fetch params from Azure"
$storageConnectionString = $(az storage account show-connection-string -g $sharedResourceGroupName -n $($sharedResourceNames.storageAccount) --query "connectionString" -o tsv)
$nodeStorageQueueName = "node-processor-queue"
$pythonStorageQueueName = "python-processor-queue"
$serviceBusNamespaceConnectionString = $(az servicebus namespace authorization-rule keys list -g $sharedResourceGroupName --namespace-name $($sharedResourceNames.serviceBus) --name 'RootManageSharedAccessKey' --query 'primaryConnectionString' -o tsv)
$serviceBusQueueName = $(az servicebus queue list -g $sharedResourceGroupName --namespace-name $($sharedResourceNames.serviceBus) --query '[0].name' -o tsv)

$sharedResourceVars = Get-SharedResourceDeploymentVars $sharedResourceGroupName $sharedRgString

$nodeProcessorContainerName = $($batchProcessorResourceNames.containerAppNodeStorageQueue)
$nodeProcessorImageTag = $(Get-Date -Format "yyyyMMddhhmm")
$nodeProcessorImageName = "$($sharedResourceVars.registryUrl)/${nodeProcessorContainerName}:${nodeProcessorImageTag}"

$nodeSbProcessorContainerName = $($batchProcessorResourceNames.containerAppNodeServiceBusQueue)
$nodeSbProcessorImageTag = $(Get-Date -Format "yyyyMMddhhmm")
$nodeSbProcessorImageName = "$($sharedResourceVars.registryUrl)/${nodeSbProcessorContainerName}:${nodeSbProcessorImageTag}"

$pythonProcessorContainerName = $($batchProcessorResourceNames.containerAppPythonStorageQueue)
$pythonProcessorImageTag = $(Get-Date -Format "yyyyMMddhhmm")
$pythonProcessorImageName = "$($sharedResourceVars.registryUrl)/${pythonProcessorContainerName}:${pythonProcessorImageTag}"

$clientContainerName = $($batchProcessorResourceNames.containerAppClient)
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

Write-Step "Provision Additional $sharedResourceGroupName Resources (What-If: $($WhatIf))"
$mainBicepFile = "$repoRoot/bicep/main.bicep"

if ($WhatIf -eq $True) {
  az deployment group create `
    -g $sharedResourceGroupName `
    -p nodeQueueName=$nodeStorageQueueName `
    pythonQueueName=$pythonStorageQueueName `
    -f $mainBicepFile `
    --what-if
}
else {
  az deployment group create `
    -g $sharedResourceGroupName `
    -p nodeQueueName=$nodeStorageQueueName `
    pythonQueueName=$pythonStorageQueueName `
    -f $mainBicepFile `
    --query "properties.provisioningState" `
    -o tsv
}

Write-Step "Create Resource Group $batchProcessorResourceGroupName"
az group create -l $resourceGroupLocation -g $batchProcessorResourceGroupName --query name -o tsv

Write-Step "Provision $batchProcessorResourceGroupName Resources (What-If: $($WhatIf))"

Write-Step "Build and Push $nodeProcessorImageName Image (What-If: $($WhatIf))"
docker build -t $nodeProcessorImageName "$repoRoot/services/node-processor"

if ($WhatIf -eq $False) {
  Write-Step "Push $nodeProcessorImageName Image (What-If: $($WhatIf))"
  docker push $nodeProcessorImageName
}
else {
  Write-Step "Skipping Push $nodeProcessorImageName Image (What-If: $($WhatIf))"
}

# TODO: Investigate why using 'az acr build' does not work
# az acr build -r $registryUrl -t $nodeProcessorImageName ./services/node-processor

Write-Step "Get Top Image from $($sharedResourceVars.registryUrl) respository $nodeProcessorContainerName to Verify Push (What-If: $($WhatIf))"
az acr repository show-tags --name $($sharedResourceVars.registryUrl)  --repository $nodeProcessorContainerName --orderby time_desc --top 1 -o tsv

Write-Step "Deploy $nodeProcessorImageName Container App (What-If: $($WhatIf))"
$nodeProcessorBicepContainerDeploymentFilePath = "$repoRoot/bicep/modules/nodeProcessorContainerApp.bicep"

if ($WhatIf -eq $True) {
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
    --what-if
}
else {
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
}

Write-Step "Build and Push $nodeSbProcessorImageName Image (What-If: $($WhatIf))"
docker build -t $nodeSbProcessorImageName "$repoRoot/services/node-sb-processor"

if ($WhatIf -eq $False) {
  Write-Step "Push $nodeSbProcessorImageName Image (What-If: $($WhatIf))"
  docker push $nodeSbProcessorImageName
}
else {
  Write-Step "Skipping Push $nodeSbProcessorImageName Image (What-If: $($WhatIf))"
}

# TODO: Investigate why using 'az acr build' does not work
# az acr build -r $registryUrl -t $nodeSbProcessorImageName "$repoRoot/services/node-sb-processor"

Write-Step "Deploy $nodeSbProcessorImageName Container App (What-If: $($WhatIf))"
$nodeSbProcessorBicepContainerDeploymentFilePath = "$repoRoot/bicep/modules/nodeServiceBusProcessorContainerApp.bicep"

if ($WhatIf -eq $True) {
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
    --what-if
}
Else {
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
}

Write-Step "Build and Push $pythonProcessorImageName Image (What-If: $($WhatIf))"
docker build -t $pythonProcessorImageName "$repoRoot/services/python-processor"

if ($WhatIf -eq $False) {
  Write-Step "Push $pythonProcessorImageName Image (What-If: $($WhatIf))"
  docker push $pythonProcessorImageName
}
else {
  Write-Step "Skipping Push $pythonProcessorImageName Image (What-If: $($WhatIf))"
}

# TODO: Investigate why using 'az acr build' does not work
# az acr build -r $registryUrl -t $pythonProcessorImageName ./services/python-processor

Write-Step "Deploy $pythonProcessorImageName Container App (What-If: $($WhatIf))"
$pythonProcessorBicepContainerDeploymentFilePath = "$repoRoot/bicep/modules/pythonProcessorContainerApp.bicep"

if ($WhatIf -eq $True) {
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
    --what-if
}
else {
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
}

Write-Step "Build and Push $clientImageName Image (What-If: $($WhatIf))"
docker build -t $clientImageName "$repoRoot/apps/website"

if ($WhatIf -eq $False) {
  Write-Step "Push $clientImageName Image (What-If: $($WhatIf))"
  docker push $clientImageName
}
else {
  Write-Step "Skipping Push $clientImageName Image (What-If: $($WhatIf))"
}

# az acr build -r $registryUrl -t $clientImageName "$repoRoot/apps/website"

Write-Step "Deploy $clientImageName Container App (What-If: $($WhatIf))"
$clientBicepContainerDeploymentFilePath = "$repoRoot/bicep/modules/clientContainerApp.bicep"

if ($WhatIf -eq $True) {
  az deployment group create `
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
    --what-if
}
else {
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
}
