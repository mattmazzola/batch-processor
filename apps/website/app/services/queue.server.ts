import { QueueServiceClient } from "@azure/storage-queue"

if (typeof process.env.STORAGE_CONNECTION_STRING !== 'string') {
    throw new Error(`You attempt to run container without providing the STORAGE_CONNECTION_STRING`)
}

if (typeof process.env.STORAGE_QUEUE_NAME !== 'string') {
    throw new Error(`You attempt to run container without providing the STORAGE_QUEUE_NAME`)
}

const queueServiceClient = QueueServiceClient.fromConnectionString(process.env.STORAGE_CONNECTION_STRING)
const queueClient = queueServiceClient.getQueueClient(process.env.STORAGE_QUEUE_NAME)
console.log(`Connected to storage account: ${queueServiceClient.accountName} queueClient: ${queueClient.name}`)

export {
    queueClient
}

