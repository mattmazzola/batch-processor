param name string = '${resourceGroup().name}-sb-node'
param location string = resourceGroup().location

param managedEnvironmentResourceId string
param imageName string
param containerName string
param registryUrl string
param registryUsername string
@secure()
param registryPassword string

param queueName string
param messageCount int = 1
param activationQueueLength int = 0
param serviceBusNamespaceName string
@secure()
param serviceBusConnectionString string

@secure()
param databaseConnectionString string

var registryPasswordSecretName = 'container-registry-password'
var databaseUrlSecretName = 'db-url'
var serviceBusConnectionStringSecretName = 'service-bus-connection-string'

resource containerApp 'Microsoft.App/containerApps@2025-02-02-preview' = {
  name: name
  location: location
  properties: {
    managedEnvironmentId: managedEnvironmentResourceId
    configuration: {
      activeRevisionsMode: 'Single'
      registries: [
        {
          server: registryUrl
          username: registryUsername
          passwordSecretRef: registryPasswordSecretName
        }
      ]
      secrets: [
        {
          name: registryPasswordSecretName
          value: registryPassword
        }
        {
          name: databaseUrlSecretName
          value: databaseConnectionString
        }
        {
          name: serviceBusConnectionStringSecretName
          value: serviceBusConnectionString
        }
      ]
    }
    template: {
      containers: [
        {
          image: imageName
          name: containerName
          resources: {
            cpu: any('0.25')
            memory: '0.5Gi'
          }
          env: [
            {
              name: 'NODE_ENV'
              value: 'development'
            }
            {
              name: 'DATABASE_URL'
              secretRef: databaseUrlSecretName
            }
            {
              name: 'SERVICE_BUS_NAMESPACE_CONNECTION_STRING'
              secretRef: serviceBusConnectionStringSecretName
            }
            {
              name: 'SERVICE_BUS_NODE_QUEUE_NAME'
              value: queueName
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 5
        rules: [
          {
            name: 'service-bus-queue-message'
            custom: {
              // https://keda.sh/docs/2.9/scalers/azure-service-bus/
              type: 'azure-servicebus'
              metadata: {
                queueName: queueName
                messageCount: string(messageCount)
                activationMessageCount: string(activationQueueLength)
                connectionFromEnv: 'SERVICE_BUS_NAMESPACE_CONNECTION_STRING'
                namespace: serviceBusNamespaceName
                cloud: 'AzurePublicCloud'
              }
              auth: [
                {
                  secretRef: serviceBusConnectionStringSecretName
                  triggerParameter: 'connnection'
                }
              ]
            }
          }
        ]
      }
    }
  }
}
