param uniqueRgString string

// global	6-50	Alphanumerics.
// https://learn.microsoft.com/en-us/azure/azure-resource-manager/management/resource-name-rules#microsoftservicebus
@minLength(6)
@maxLength(50)
param serviceBusName string = '${resourceGroup().name}-${uniqueRgString}-servicebus'

resource serviceBusNamespace 'Microsoft.ServiceBus/namespaces@2022-10-01-preview' existing = {
  name: serviceBusName
}

param nodeQueueName string = 'node-sb-processor-queue'

resource nodeQueue 'Microsoft.ServiceBus/namespaces/queues@2022-10-01-preview' = {
  parent: serviceBusNamespace
  name: nodeQueueName
  properties: {
    defaultMessageTimeToLive: 'P1D'
  }
}
