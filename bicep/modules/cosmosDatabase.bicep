resource databaseAccount 'Microsoft.DocumentDB/databaseAccounts@2022-08-15' existing = {
  name: 'shared-klgoyi-cosmos'
}

param databaseName string = 'valorantwomen'

resource sqlDatabase 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases@2022-08-15' = {
  parent: databaseAccount
  name: databaseName
  properties: {
    resource: {
      id: databaseName
    }
  }
}

param containerName string = 'ratings'

resource container 'Microsoft.DocumentDB/databaseAccounts/sqlDatabases/containers@2022-08-15' = {
  parent: sqlDatabase
  name: containerName
  properties: {
    resource: {
      id: containerName
      indexingPolicy: {
        indexingMode: 'consistent'
        automatic: true
        includedPaths: [
          {
            path: '/*'
          }
        ]
        excludedPaths: [
          {
            path: '/"_etag"/?'
          }
        ]
      }
      partitionKey: {
        paths: [
          '/userId'
        ]
        kind: 'Hash'
      }
      uniqueKeyPolicy: {
        uniqueKeys: [
          {
            paths: [
              '/userId'
              '/isWomen'
            ]
          }
        ]
      }
      conflictResolutionPolicy: {
        mode: 'LastWriterWins'
        conflictResolutionPath: '/_ts'
      }
    }
  }
}


output accountName string = databaseAccount.name
output databaseName string = sqlDatabase.name
output containerName string = container.name
