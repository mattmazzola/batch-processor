param name string = '${resourceGroup().name}-node'
param location string = resourceGroup().location

param managedEnvironmentResourceId string
param imageName string
param containerName string
param registryUrl string
param registryUsername string
@secure()
param registryPassword string

param queueName string
param queueLength int = 1
param activationQueueLength int = 0
param storageAccountName string
@secure()
param storageConnectionString string

@secure()
param databaseConnectionString string
@secure()
param shadowDatabaseConnectionString string

var registryPassworldSecretName = 'container-registry-password'
var databaseUrlSecretName = 'db-url'
var shadowDatabaseUrlSecretName = 'shadow-db-url'
var storageConnectionStringSecretName = 'queue-connection-string'

resource containerApp 'Microsoft.App/containerapps@2022-03-01' = {
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
          name: shadowDatabaseUrlSecretName
          value: shadowDatabaseConnectionString
        }
        {
          name: storageConnectionStringSecretName
          value: storageConnectionString
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
              name: 'SHADOW_DATABASE_URL'
              secretRef: databaseUrlSecretName
            }
            {
              name: 'STORAGE_CONNECTION_STRING'
              secretRef: storageConnectionStringSecretName
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 5
        rules: [
          {
            name: 'storage-queue-message'
            custom: {
              type: 'azure-queue'
              metadata: {
                queueName: queueName
                queueLength: string(queueLength)
                activationQueueLength: string(activationQueueLength)
                connectionFromEnv: 'STORAGE_CONNECTION_STRING'
                accountName: storageAccountName
                cloud: 'AzurePublicCloud'
              }
            }
          }
        ]
      }
    }
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
