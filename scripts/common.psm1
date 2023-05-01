
function Get-LocalResourceNames {
    param (
        [Parameter(Mandatory = $true, Position = 0)]
        [string]$resourceGroupName,
        [Parameter(Mandatory = $true, Position = 1)]
        [string]$uniqueRgString
    )

    $resourceNames = [ordered]@{
        containerAppClient = "batch-processor-client"
        containerAppNodeStorageQueue = "batch-processor-node"
        containerAppNodeServiceBusQueue = "batch-processor-sb-node"
        containerAppPythonStorageQueue = "batch-processor-python"
        serviceBus = "batch-processor-servicebus"
        sqlDatabaseName = "shared-kylogi-sql-db-batch-processor"
        storageQueueNode = "node-processor-queue"
        storageQueuePython = "python-processor-queue"
    }

    return $resourceNames
}
