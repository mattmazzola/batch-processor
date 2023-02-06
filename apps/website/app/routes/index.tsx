import { DataFunctionArgs, LinksFunction } from "@remix-run/node"
import { Form, useLoaderData } from "@remix-run/react"
import React, { createRef } from "react"
import { secondsPerMinute } from "~/constants"
import { db } from "~/services/db.server"
import { nodeQueueClient, pythonQueueClient } from "~/services/queue.server"
import indexStyles from "~/styles/index.css"

export const links: LinksFunction = () => [
  { rel: "stylesheet", href: indexStyles },
]

export const loader = async ({ request }: DataFunctionArgs) => {
  const items = await db.item.findMany()
  const results = await db.result.findMany()

  const nodeMessagesResponse = await nodeQueueClient.peekMessages({ numberOfMessages: 32 })
  const nodeMessageCount = nodeMessagesResponse.peekedMessageItems.length

  const pythonMessagesResponse = await pythonQueueClient.peekMessages({ numberOfMessages: 32 })
  const pythonMessageCount = pythonMessagesResponse.peekedMessageItems.length

  return {
    items,
    results,
    nodeMessageCount,
    pythonMessageCount,
  }
}

enum FormSubmissionNames {
  AddValue = 'AddValue',
  ProcessValues = 'ProcessValues',
}

enum QueueTypes {
  NodeStorage = 'Node Storage',
  NodeServiceBus = 'Node Service Bus',
  PythonStorage = 'Python Storage',
}

type MessageContent = {
  source: string
  datetime: string
  input: {
    numberValue: number
    stringValue: string
  }
}

export const action = async ({ request }: DataFunctionArgs) => {
  const rawFormData = await request.formData()
  const formData = Object.fromEntries(rawFormData)
  const formName = formData.formName as string

  console.log({ formName })

  switch (formName) {
    case FormSubmissionNames.AddValue: {
      const value = Number(formData.value)
      console.log({ value })

      await db.item.create({
        data: {
          userId: 'hardcoded-userid-for-testing',
          value
        }
      })
      break
    }

    case FormSubmissionNames.ProcessValues: {
      const queueType = formData.queueType as QueueTypes
      const messageJson: MessageContent = {
        source: queueType,
        datetime: new Date().toJSON(),
        input: {
          numberValue: 10,
          stringValue: 'abc'
        }
      }

      switch (queueType) {
        case QueueTypes.NodeStorage: {
          const addedMessage = await nodeQueueClient.sendMessage(JSON.stringify(messageJson), {
            messageTimeToLive: 10 * secondsPerMinute
          })

          console.log(`Added message: ${addedMessage.messageId} to ${queueType} queue!`)
          break
        }
        case QueueTypes.PythonStorage: {
          const addedMessage = await pythonQueueClient.sendMessage(JSON.stringify(messageJson), {
            messageTimeToLive: 10 * secondsPerMinute
          })

          console.log(`Added message: ${addedMessage.messageId} to ${queueType} queue!`)
          break
        }
        default: {
          console.warn(`Queue type ${queueType} not implemented!`)
        }
      }

      break
    }
  }

  return null
}

export default function Index() {
  const { items, results, nodeMessageCount, pythonMessageCount } = useLoaderData<typeof loader>()
  const valueInputRef = createRef<HTMLInputElement>()
  const submitButtonRef = createRef<HTMLButtonElement>()
  const setRandom = () => {
    if (valueInputRef.current) {
      const randomValue = Math.floor(Math.random() * 1000)
      valueInputRef.current.value = randomValue.toString()

      if (submitButtonRef.current) {
        submitButtonRef.current.click()
      }
    }
  }

  const dateFormatter = new Intl.DateTimeFormat("en-US", {
    weekday: 'short',
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  })

  return (
    <>
      <h1>Add Item:</h1>
      <Form method="post" className="addValueForm">
        <input type="hidden" name="formName" value={FormSubmissionNames.AddValue} />
        <div className="row">
          <label htmlFor="value">Value: </label>
          <input ref={valueInputRef} type="number" id="value" name="value" step={1} required defaultValue={0} />
        </div>
        <div className="row">
          <button ref={submitButtonRef} type="submit">Add Value</button>
          <button type="button" onClick={setRandom}>Add Random value</button>
        </div>
      </Form>
      <h1>Process Items:</h1>
      <div className="processingForm">
        <Form method="post" className="processingQueue">
          <input type="hidden" name="formName" value={FormSubmissionNames.ProcessValues} />
          <input type="hidden" name="queueType" value={QueueTypes.NodeStorage} />
          <div>Queue: {QueueTypes.NodeStorage}</div>
          <div>Size: {nodeMessageCount}</div>
          <button type="submit">Add Message</button>
        </Form>
        <Form method="post" className="processingQueue">
          <input type="hidden" name="formName" value={FormSubmissionNames.ProcessValues} />
          <input type="hidden" name="queueType" value={QueueTypes.NodeServiceBus} />
          <div>Queue: {QueueTypes.NodeServiceBus}</div>
          <div>Size: -</div>
          <button type="submit">Add Message</button>
        </Form>
        <Form method="post" className="processingQueue">
          <input type="hidden" name="formName" value={FormSubmissionNames.ProcessValues} />
          <input type="hidden" name="queueType" value={QueueTypes.PythonStorage} />
          <div>Queue: {QueueTypes.PythonStorage}</div>
          <div>Size: {pythonMessageCount}</div>
          <button type="submit">Add Message</button>
        </Form>
      </div>
      <div className="columns">
        <div>
          <h1>Items ({items.length}):</h1>
          <div className="items">
            <div className="header">ID</div>
            <div className="header">Value</div>
            <div className="header">Created At</div>
            {items.length === 0
              ? <div className="empty">No Items</div>
              : items.map(item => {
                return <React.Fragment key={item.id}>
                  <div>{item.id}</div>
                  <div><b>{item.value}</b></div>
                  <div>{dateFormatter.format(new Date(item.createdAt))}</div>
                </React.Fragment>
              })}
          </div>
        </div>
        <div>
          <h1>Results ({results.length}):</h1>
          <div className="items">
            <div className="header">Value</div>
            <div className="header">Message</div>
            <div className="header">Created At</div>
            {results.length === 0
              ? <div className="empty">No Items</div>
              : results.map(result => {
                return <React.Fragment key={result.id}>
                  <div><b>{result.value}</b></div>
                  <div>{result.message}</div>
                  <div>{dateFormatter.format(new Date(result.createdAt))}</div>
                </React.Fragment>
              })}
          </div>
        </div>
      </div>
    </>
  )
}
