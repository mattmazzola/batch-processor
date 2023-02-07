import { ServiceBusClient } from "@azure/service-bus"
import { PrismaClient } from "@prisma/client"

console.log(`Validate environment variables...`)
if (typeof process.env.DATABASE_URL !== 'string') {
    throw new Error(`You attempted to run the container without providing the DATABASE_URL`)
}

if (typeof process.env.SERVICE_BUS_NAMESPACE_CONNECTION_STRING !== 'string') {
    throw new Error(`You attempt to create service bus queue service without providing the SERVICE_BUS_NAMESPACE_CONNECTION_STRING`)
}

if (typeof process.env.SERVICE_BUS_NODE_QUEUE_NAME !== 'string') {
    throw new Error(`You attempt to create service bus node queue without providing the SERVICE_BUS_NODE_QUEUE_NAME`)
}

const serviceBusClient = new ServiceBusClient(process.env.SERVICE_BUS_NAMESPACE_CONNECTION_STRING)
const serviceBusQueueReceiver = serviceBusClient.createReceiver(process.env.SERVICE_BUS_NODE_QUEUE_NAME)

console.log(`Connected to service bus: ${serviceBusClient.identifier} queue receiver: ${serviceBusQueueReceiver.entityPath}`)

const messages = await serviceBusQueueReceiver.receiveMessages(1, {
    maxWaitTimeInMs: 500
})
if (messages.length === 0) {
    console.log(`There were no messages in the queue. Exiting early`)
    process.exit(0)
}

type MessageContent = {
    source: string
    datetime: string
    input: {
        numberValue: number
        stringValue: string
    }
}

const message = messages.at(0)!
const messageJson = message.body.endsWith('=')
    ? new TextDecoder().decode(Uint8Array.from(Buffer.from(message.body, 'base64')))
    : message.body
const messageObject: MessageContent = messageJson.startsWith('{')
    ? JSON.parse(messageJson)
    : messageJson

const timeFormatter = new Intl.RelativeTimeFormat('en-US', {
    numeric: 'auto'
})

const insertedDifference = Date.now() - (message.enqueuedTimeUtc?.getTime() ?? Date.now())
const insertedDifferenceMinutes = insertedDifference / 1000 / 60
const expireDifference = Date.now() - (message.expiresAtUtc?.getTime() ?? Date.now())
const expireDifferenceMinutes = expireDifference / 1000 / 60

console.log(`Message: ${message.messageId} received on: ${timeFormatter.format(-insertedDifferenceMinutes, 'minutes')}, expiresOn: ${timeFormatter.format(-expireDifferenceMinutes, 'minutes')}`)
console.log(`
Source: ${messageObject.source}
Time: ${messageObject.datetime}
Number: ${messageObject.input.numberValue}
String: ${messageObject.input.stringValue}
`.trim())

console.log(`Dequeuing message: ${message.messageId}`)
await serviceBusQueueReceiver.completeMessage(message)

console.log(`Fetch items from database...`)
const db = new PrismaClient()
const items = await db.item.findMany()
const values = items.map(i => i.value)

console.log(`Add up ${values.length} values: [${values.join(', ')}]`)
const total = values.reduce((sum, value) => sum + value, 0)

const savedResult = await db.result.create({
    data: {
        value: total,
        message: `Number: ${messageObject.input.numberValue} String: ${messageObject.input.stringValue} from Node`
    }
})

console.log(`Saved sum: ${savedResult.value}`)
process.exit(0)
