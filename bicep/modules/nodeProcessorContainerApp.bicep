param name string = '${resourceGroup().name}-containerapp-service'
param location string = resourceGroup().location

param managedEnvironmentResourceId string
param imageName string
param containerName string
param registryUrl string
param registryUsername string
@secure()
param registryPassword string

param databaseAccountUrl string
@secure()
param databaseKey string

param queueName string
param queueLength int
@secure()
param queueSecret string

var registryPassworldSecretName = 'container-registry-password'
var databaseUrlSecretName = 'db-url'
var shadowDatabaseUrlSecretName = 'shadow-db-url'
var queueSecretName = 'queue-secret'

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
          name: queueSecretName
          value: queueSecret
        }
        {
          name: databaseUrlSecretName
          value: databaseKey
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
          ]
        }
      ]
      scale: {
        minReplicas: 0
        maxReplicas: 1
        rules: [
          {
            azureQueue: {
              queueName: queueName
              queueLength: queueLength
              auth: [
                {
                  triggerParameter: 'connection-string'
                  secretRef: queueSecretName
                }
              ]
            }
          }
        ]
      }
    }
  }
}

output fqdn string = containerApp.properties.configuration.ingress.fqdn
