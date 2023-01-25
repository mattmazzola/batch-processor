$sharedResourceGroupName = "shared"
$sharedRgString = 'klgoyi'
$resourceGroupName = "batch-processor"
$resourceGroupLocation = "westus3"

Import-Module "C:/repos/shared-resources/pipelines/scripts/common.psm1" -Force

Write-Step "Create Resource Group: $resourceGroupName"
az group create -l $resourceGroupLocation -g $resourceGroupName --query name -o tsv

$envFilePath = $(Resolve-Path "$PSScriptRoot/../services/processor/.env").Path
Write-Step "Get ENV Vars from $envFilePath"
$databaseConnectionString = Get-EnvVarFromFile -envFilePath $envFilePath -variableName 'DATABASE_URL'
$shadowDatabaseConnectionString = Get-EnvVarFromFile -envFilePath $envFilePath -variableName 'SHADOW_DATABASE_URL'
$storageConnectionString = Get-EnvVarFromFile -envFilePath $envFilePath -variableName 'STORAGE_CONNECTION_STRING'

Write-Step "Fetch params from Azure"
$sharedResourceNames = Get-ResourceNames $sharedResourceGroupName $sharedRgString

$containerAppsEnvResourceId = $(az containerapp env show -g $sharedResourceGroupName -n $sharedResourceNames.containerAppsEnv --query "id" -o tsv)
$acrJson = $(az acr credential show -n $sharedResourceNames.containerRegistry --query "{ username:username, password:passwords[0].value }" | ConvertFrom-Json)
$registryUrl = $(az acr show -g $sharedResourceGroupName -n $sharedResourceNames.containerRegistry --query "loginServer" -o tsv)
$registryUsername = $acrJson.username
$registryPassword = $acrJson.password

$nodeProcessorContainerName = "$resourceGroupName-node"
$nodeProcessorImageTag = $(Get-Date -Format "yyyyMMddhhmm")
$nodeProcessorImageName = "${registryUrl}/${nodeProcessorContainerName}:${nodeProcessorImageTag}"

$clientContainerName = "$resourceGroupName-client"
$clientImageTag = $(Get-Date -Format "yyyyMMddhhmm")
$clientImageName = "${registryUrl}/${clientContainerName}:${clientImageTag}"

$data = [ordered]@{
  "databaseConnectionString"       = "$($databaseConnectionString.Substring(0, 15))..."
  "shadowDatabaseConnectionString" = "$($shadowDatabaseConnectionString.Substring(0, 15))..."
  "storageConnectionString"        = "$($storageConnectionString.Substring(0, 15))..."

  "nodeProcessorImageName"         = $nodeProcessorImageName
  "clientImageName"                = $clientImageName

  "containerAppsEnvResourceId"     = $containerAppsEnvResourceId
  "registryUrl"                    = $registryUrl
  "registryUsername"               = $registryUsername
  "registryPassword"               = "$($registryPassword.Substring(0, 5))..."
}

Write-Hash "Data" $data

# Write-Step "Build and Push $serviceImageName Image"
# docker build -t $serviceImageName ./service
# docker push $serviceImageName
# # TODO: Investigate why using 'az acr build' does not work
# # az acr build -r $registryUrl -t $serviceImageName ./service

# Write-Step "Deploy $serviceImageName Container App"
# $serviceBicepContainerDeploymentFilePath = "$PSScriptRoot/../../bicep/modules/serviceContainerApp.bicep"
# $serviceFqdn = $(az deployment group create `
#     -g $resourceGroupName `
#     -f $serviceBicepContainerDeploymentFilePath `
#     -p managedEnvironmentResourceId=$containerAppsEnvResourceId `
#     registryUrl=$registryUrl `
#     registryUsername=$registryUsername `
#     registryPassword=$registryPassword `
#     imageName=$serviceImageName `
#     containerName=$serviceContainerName `
#     databaseAccountUrl=$dbAccountUrl `
#     databaseKey=$dbKey `
#     --query "properties.outputs.fqdn.value" `
#     -o tsv)

# $apiUrl = "https://$serviceFqdn"
# Write-Output $apiUrl

# Write-Step "Build and Push $clientImageName Image"
# az acr build -r $registryUrl -t $clientImageName ./client-remix

# Write-Step "Deploy $clientImageName Container App"
# $clientBicepContainerDeploymentFilePath = "$PSScriptRoot/../../bicep/modules/clientContainerApp.bicep"
# $clientFqdn = $(az deployment group create `
#     -g $resourceGroupName `
#     -f $clientBicepContainerDeploymentFilePath `
#     -p managedEnvironmentResourceId=$containerAppsEnvResourceId `
#     registryUrl=$registryUrl `
#     registryUsername=$registryUsername `
#     registryPassword=$registryPassword `
#     imageName=$clientImageName `
#     containerName=$clientContainerName `
#     apiUrl=$apiUrl `
#     auth0ReturnToUrl=$auth0ReturnToUrl `
#     auth0CallbackUrl=$auth0CallbackUrl `
#     auth0ClientId=$auth0ClientId `
#     auth0ClientSecret=$auth0ClientSecret `
#     auth0Domain=$auth0Domain `
#     auth0LogoutUrl=$auth0LogoutUrl `
#     auth0managementClientId=$auth0managementClientId `
#     auth0managementClientSecret=$auth0managementClientSecret `
#     cookieSecret=$cookieSecret `
#     --query "properties.outputs.fqdn.value" `
#     -o tsv)

# $clientUrl = "https://$clientFqdn"
# Write-Output $clientUrl

# Write-Output "Service URL: $apiUrl"
# Write-Output "Client URL: $clientUrl"