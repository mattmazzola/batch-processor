import { DataFunctionArgs, LinksFunction } from "@remix-run/node"
import { Form, useLoaderData } from "@remix-run/react"
import React, { createRef } from "react"
import { millisecondsPerMinute } from "~/constants"
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
  const nodeMessageCount =  nodeMessagesResponse.peekedMessageItems.length

  const pythonMessagesResponse = await pythonQueueClient.peekMessages({ numberOfMessages: 32 })
  const pythonMessageCount =  pythonMessagesResponse.peekedMessageItems.length

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
  Node = 'Node',
  Python = 'Python',
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
          userId: 'abc123',
          value
        }
      })
      break
    }
    case FormSubmissionNames.ProcessValues: {
      const queueType = formData.queueType as QueueTypes

      switch (queueType) {
        case QueueTypes.Node: {
          const addedMessage = await nodeQueueClient.sendMessage(`Message Text in ${queueType} Queue from Batch-Processor Website at ${new Date().toJSON()}`, {
            messageTimeToLive: 1 * millisecondsPerMinute
          })

          console.log(`Added message: ${addedMessage.messageId} to ${queueType} queue!`)
          break;
        }
        case QueueTypes.Python: {
          const addedMessage = await pythonQueueClient.sendMessage(`Message Text in ${queueType} Queue from Batch-Processor Website at ${new Date().toJSON()}`, {
            messageTimeToLive: 1 * millisecondsPerMinute
          })

          console.log(`Added message: ${addedMessage.messageId} to ${queueType} queue!`)
          break;
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
        <Form method="post" >
          <input type="hidden" name="formName" value={FormSubmissionNames.ProcessValues} />
          <input type="hidden" name="queueType" value={QueueTypes.Node} />
          <button type="submit">{`Add to Node Queue (Size ${nodeMessageCount})`}</button>
        </Form>
        <Form method="post" >
          <input type="hidden" name="formName" value={FormSubmissionNames.ProcessValues} />
          <input type="hidden" name="queueType" value={QueueTypes.Python} />
          <button type="submit">{`Add to Python Queue (Size ${pythonMessageCount})`}</button>
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
            <div className="header">ID</div>
            <div className="header">Value</div>
            <div className="header">Created At</div>
            {results.length === 0
              ? <div className="empty">No Items</div>
              : results.map(result => {
                return <React.Fragment key={result.id}>
                  <div>{result.id}</div>
                  <div><b>{result.value}</b></div>
                  <div>{dateFormatter.format(new Date(result.createdAt))}</div>
                </React.Fragment>
              })}
          </div>
        </div>
      </div>
    </>
  )
}
