var uniqueRgString = take(uniqueString(resourceGroup().id), 6)

param nodeQueueName string
param pythonQueueName string

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
    nodeQueueName: nodeQueueName
    pythonQueueName: pythonQueueName
  }
}

module serviceQueues 'modules/serviceQueues.bicep' = {
  name: 'serviceQueuesModule'
  params: {
    uniqueRgString: uniqueRgString
  }
}
