var uniqueRgString = take(uniqueString(resourceGroup().id), 6)

module sqlDatabase 'modules/sqlDatabase.bicep' = {
  name: 'sqlDatabaseModule'
  params: {
    uniqueRgString: uniqueRgString
  }
}

module storageQueues 'modules/storageQueues.bicep' = {
  name: 'storageQueuesModule'
  params: {
    uniqueRgString: uniqueRgString
  }
}
