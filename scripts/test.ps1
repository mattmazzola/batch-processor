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

echo $sharedResourceGroupName
echo $($sharedResourceNames.storageAccount)

Write-Step "Fetch params from Azure"
$storageConnectionString = $(az storage account show-connection-string -g $sharedResourceGroupName -n $($sharedResourceNames.storageAccount) --query "connectionString" -o tsv)
# $nodeStorageQueueName = "$(az storage queue list --connection-string $storageConnectionString --query "[0].name" -o tsv)"
$nodeStorageQueueName = "node-processor-queue"
# $pythonStorageQueueName = $(az storage queue list --connection-string $storageConnectionString --query "[1].name" -o tsv)
$pythonStorageQueueName = "python-processor-queue"

echo $storageConnectionString
echo $nodeStorageQueueName
echo $pythonStorageQueueName
