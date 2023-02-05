param uniqueRgString string

// global	3-24 Alphanumerics.
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftstorage
@minLength(3)
@maxLength(24)
param name string = '${resourceGroup().name}${uniqueRgString}storage'

resource storageAccount 'Microsoft.Storage/storageAccounts@2022-05-01' existing = {
  name: name
}

resource queueService 'Microsoft.Storage/storageAccounts/queueServices@2022-05-01' existing = {
  parent: storageAccount
  name: 'default'
}

param nodeQueueName string = 'node-processor-queue'

resource nodeProcessorQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2022-05-01' = {
  parent: queueService
  name: nodeQueueName
}

param pythonQueueName string = 'python-processor-queue'

resource pythonProcessorQueue 'Microsoft.Storage/storageAccounts/queueServices/queues@2022-05-01' = {
  parent: queueService
  name: pythonQueueName
}
