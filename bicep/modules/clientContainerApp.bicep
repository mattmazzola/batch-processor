param name string = '${resourceGroup().name}-client'
param location string = resourceGroup().location

param managedEnvironmentResourceId string
param imageName string
param containerName string
param registryUrl string
param registryUsername string
@secure()
param registryPassword string

param nodeQueueName string
param pythonQueueName string
@secure()
param storageConnectionString string

@secure()
param serviceBusConnectionString string
param serviceBusQueueName string

@secure()
param databaseConnectionString string

var registryPassworldSecretName = 'container-registry-password'
var databaseUrlSecretName = 'db-url'
var storageConnectionStringSecretName = 'queue-connection-string'
var serviceBusConnectionStringSecretName = 'service-bus-queue-connection-string'

resource containerApp 'Microsoft.App/containerapps@2022-03-01' = {
  name: name
  location: location
  properties: {
    managedEnvironmentId: managedEnvironmentResourceId
    configuration: {
      activeRevisionsMode: 'Single'
      ingress: {
        external: true
        targetPort: 8080
      }
      registries: [
        {
          server: registryUrl
          username: registryUsername
          passwordSecretRef: registryPassworldSecretName
        }
      ]
      secrets: [
        {
          name: registryPassworldSecretName
          value: registryPassword
        }
        {
          name: databaseUrlSecretName
          value: databaseConnectionString
        }
        {
          name: storageConnectionStringSecretName
          value: storageConnectionString
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
          // https://learn.microsoft.com/en-us/azure/container-apps/containers#configuration
          resources: {
            cpu: any('0.5')
            memory: '1.0Gi'
          }
          env: [
            {
              name: 'DATABASE_URL'
              secretRef: databaseUrlSecretName
            }
            {
              name: 'STORAGE_CONNECTION_STRING'
              secretRef: storageConnectionStringSecretName
            }
            {
              name: 'STORAGE_NODE_QUEUE_NAME'
              value: nodeQueueName
            }
            {
              name: 'STORAGE_PYTHON_QUEUE_NAME'
              value: pythonQueueName
            }
            {
              name: 'SERVICE_BUS_NAMESPACE_CONNECTION_STRING'
              secretRef: serviceBusConnectionStringSecretName
            }
            {
              name: 'SERVICE_BUS_NODE_QUEUE_NAME'
              value: serviceBusQueueName
            }
          ]
        }
      ]
      scale: {
        minReplicas: 1
        maxReplicas: 1
      }
    }
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
