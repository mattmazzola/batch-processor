import { QueueClient, QueueServiceClient } from "@azure/storage-queue"

if (typeof process.env.STORAGE_CONNECTION_STRING !== 'string') {
    throw new Error(`You attempt to run container without providing the STORAGE_CONNECTION_STRING`)
}

if (typeof process.env.STORAGE_QUEUE_NAME !== 'string') {
    throw new Error(`You attempt to run container without providing the STORAGE_QUEUE_NAME`)
}


let queueServiceClient: QueueServiceClient
let queueClient: QueueClient

declare global {
    var __queueServiceClient: QueueServiceClient | undefined
    var __queueClient: QueueClient | undefined
}

// this is needed because in development we don't want to restart
// the server with every change, but we want to make sure we don't
// create a new connection to the DB with every change either.
if (process.env.NODE_ENV === "production") {
    queueServiceClient = QueueServiceClient.fromConnectionString(process.env.STORAGE_CONNECTION_STRING)
    queueClient = queueServiceClient.getQueueClient(process.env.STORAGE_QUEUE_NAME)
} else {
    if (!global.__queueServiceClient) {
        global.__queueServiceClient = QueueServiceClient.fromConnectionString(process.env.STORAGE_CONNECTION_STRING)
    }

    queueServiceClient = global.__queueServiceClient

    if (!global.__queueClient) {
        global.__queueClient = global.__queueServiceClient.getQueueClient(process.env.STORAGE_QUEUE_NAME)
    }

    queueClient = global.__queueClient
}

export {
    queueClient
}

