import { QueueClient, QueueServiceClient } from "@azure/storage-queue"

if (typeof process.env.STORAGE_CONNECTION_STRING !== 'string') {
    throw new Error(`You attempt to create queue service without providing the STORAGE_CONNECTION_STRING`)
}

if (typeof process.env.STORAGE_NODE_QUEUE_NAME !== 'string') {
    throw new Error(`You attempt to create node queue without providing the STORAGE_NODE_QUEUE_NAME`)
}

if (typeof process.env.STORAGE_PYTHON_QUEUE_NAME !== 'string') {
    throw new Error(`You attempt to create python queue without providing the STORAGE_PYTHON_QUEUE_NAME`)
}

let queueServiceClient: QueueServiceClient
let nodeQueueClient: QueueClient
let pythonQueueClient: QueueClient

declare global {
    var __queueServiceClient: QueueServiceClient | undefined
    var __nodeQueueClient: QueueClient | undefined
    var __pythonQueueClient: QueueClient | undefined
}

// this is needed because in development we don't want to restart
// the server with every change, but we want to make sure we don't
// create a new connection to the DB with every change either.
if (process.env.NODE_ENV === "production") {
    queueServiceClient = QueueServiceClient.fromConnectionString(process.env.STORAGE_CONNECTION_STRING)
    nodeQueueClient = queueServiceClient.getQueueClient(process.env.STORAGE_NODE_QUEUE_NAME)
    pythonQueueClient = queueServiceClient.getQueueClient(process.env.STORAGE_PYTHON_QUEUE_NAME)
} else {
    if (!global.__queueServiceClient) {
        global.__queueServiceClient = QueueServiceClient.fromConnectionString(process.env.STORAGE_CONNECTION_STRING)
    }

    queueServiceClient = global.__queueServiceClient

    if (!global.__nodeQueueClient || !global.__pythonQueueClient) {
        global.__nodeQueueClient = global.__queueServiceClient.getQueueClient(process.env.STORAGE_NODE_QUEUE_NAME)
        global.__pythonQueueClient = global.__queueServiceClient.getQueueClient(process.env.STORAGE_PYTHON_QUEUE_NAME)
    }

    nodeQueueClient = global.__nodeQueueClient
    pythonQueueClient = global.__pythonQueueClient
}

export {
    nodeQueueClient,
    pythonQueueClient,
}

