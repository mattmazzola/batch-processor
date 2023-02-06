import { ServiceBusClient, ServiceBusSender } from "@azure/service-bus"

if (typeof process.env.SERVICE_BUS_NAMESPACE_CONNECTION_STRING !== 'string') {
    throw new Error(`You attempt to create service bus queue service without providing the SERVICE_BUS_NAMESPACE_CONNECTION_STRING`)
}

if (typeof process.env.SERVICE_BUS_NODE_QUEUE_NAME !== 'string') {
    throw new Error(`You attempt to create service bus node queue without providing the SERVICE_BUS_NODE_QUEUE_NAME`)
}

let serviceBusClient: ServiceBusClient
let serviceBusQueueSender: ServiceBusSender

declare global {
    var __serviceBusClient: ServiceBusClient | undefined
    var __serviceBusQueueSender: ServiceBusSender | undefined
}

// this is needed because in development we don't want to restart
// the server with every change, but we want to make sure we don't
// create a new connection to the DB with every change either.
if (process.env.NODE_ENV === "production") {
    serviceBusClient = new ServiceBusClient(process.env.SERVICE_BUS_NAMESPACE_CONNECTION_STRING)
} else {
    if (!global.__serviceBusClient) {
        global.__serviceBusClient = new ServiceBusClient(process.env.SERVICE_BUS_NAMESPACE_CONNECTION_STRING)
    }

    serviceBusClient = global.__serviceBusClient

    if (!global.__serviceBusQueueSender) {
        global.__serviceBusQueueSender = serviceBusClient.createSender(process.env.SERVICE_BUS_NODE_QUEUE_NAME)
    }

    serviceBusQueueSender = global.__serviceBusQueueSender
}

export {
    serviceBusClient,
    serviceBusQueueSender,
}

