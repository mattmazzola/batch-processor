import { QueueServiceClient } from "@azure/storage-queue"
import { PrismaClient } from "@prisma/client"
import dotenv from 'dotenv-flow'

dotenv.config()

console.log(`Validate environment variables...`)
if (typeof process.env.DATABASE_URL !== 'string') {
    throw new Error(`You attempted to run the container without providing the DATABASE_URL`)
}

if (typeof process.env.STORAGE_CONNECTION_STRING !== 'string') {
    throw new Error(`You attempted to run the container without providing the STORAGE_CONNECTION_STRING`)
}

if (typeof process.env.STORAGE_QUEUE_NAME !== 'string') {
    throw new Error(`You attempted to run the container without providing the STORAGE_QUEUE_NAME`)
}

const queueServiceClient = QueueServiceClient.fromConnectionString(process.env.STORAGE_CONNECTION_STRING)
const queueClient = queueServiceClient.getQueueClient(process.env.STORAGE_QUEUE_NAME)
console.log(`Connected to storage account: ${queueServiceClient.accountName} queueClient: ${queueClient.name}`)

const messageResponse = await queueClient.receiveMessages({ numberOfMessages: 1 })
if (messageResponse.receivedMessageItems.length === 0) {
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

const message = messageResponse.receivedMessageItems.at(0)!
const messageJson = message.messageText.endsWith('=')
    ? new TextDecoder().decode(Uint8Array.from(Buffer.from(message.messageText, 'base64')))
    : message.messageText
const messageObject: MessageContent = messageJson.startsWith('{')
    ? JSON.parse(messageJson)
    : messageJson

const timeFormatter = new Intl.RelativeTimeFormat('en-US', {
    numeric: 'auto'
})

const insertedDifference = Date.now() - message.insertedOn.getTime()
const insertedDifferenceMinutes = insertedDifference / 1000 / 60
const expireDifference = Date.now() - message.expiresOn.getTime()
const expireDifferenceMinutes = expireDifference / 1000 / 60

console.log(`Message: ${message.messageId} received on: ${timeFormatter.format(-insertedDifferenceMinutes, 'minutes')}, expiresOn: ${timeFormatter.format(-expireDifferenceMinutes, 'minutes')}`)
console.log(`
Source: ${messageObject.source}
Time: ${messageObject.datetime}
Number: ${messageObject.input.numberValue}
String: ${messageObject.input.stringValue}
`.trim())

console.log(`Dequeuing message: ${message.messageId}`)
await queueClient.deleteMessage(message.messageId, message.popReceipt)

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
