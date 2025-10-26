param uniqueRgString string

// global	3-24 Alphanumerics.
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftstorage
@minLength(3)
@maxLength(24)
param name string = '${resourceGroup().name}${uniqueRgString}storage'

resource storageAccount 'Microsoft.Storage/storageAccounts@2025-01-01' existing = {
  name: name
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2025-01-01' existing = {
  parent: storageAccount
  name: 'default'
}

param nodeQueueName string

resource nodeProcessorQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2025-01-01' = {
  parent: queueService
  name: nodeQueueName
}

param pythonQueueName string

resource pythonProcessorQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2025-01-01' = {
  parent: queueService
  name: pythonQueueName
}
