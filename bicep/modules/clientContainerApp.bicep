param name string = '${resourceGroup().name}-client'
param location string = resourceGroup().location

param managedEnvironmentResourceId string
param imageName string
param containerName string
param registryUrl string
param registryUsername string
@secure()
param registryPassword string

param queueName string
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
              name: 'SHADOW_DATABASE_URL'
              secretRef: databaseUrlSecretName
            }
            {
              name: 'STORAGE_CONNECTION_STRING'
              secretRef: storageConnectionStringSecretName
            }
            {
              name: 'STORAGE_QUEUE_NAME'
              value: queueName
            }
          ]
          probes: [
            {
              type: 'Liveness'
              httpGet: {
                path: '/'
                port: 80
              }
            }
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
      }
    }
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
