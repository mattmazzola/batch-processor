import { DataFunctionArgs, LinksFunction } from "@remix-run/node"
import { Form, useLoaderData } from "@remix-run/react"
import indexStyles from "~/styles/index.css"
import { db } from "~/services/db.server"
import React, { createRef } from "react"

export const links: LinksFunction = () => [
  { rel: "stylesheet", href: indexStyles },
]

export const loader = async ({ request }: DataFunctionArgs) => {
  const items = await db.item.findMany()
  const results = await db.result.findMany()

  return {
    items,
    results,
  }
}

enum FormSubmissionNames {
  AddValue = 'AddValue',
  ProcessValues = 'ProcessValues',
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
      console.log(`Process Values`)
      break
    }
  }

  return null
}

export default function Index() {
  const { items, results } = useLoaderData<typeof loader>()
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
    hour: '2-digit',
    minute: '2-digit',
    second: '2-digit',
  })

  return (
    <>
      <h1>Enter a value:</h1>
      <Form method="post" className="addValueForm">
        <input type="hidden" name="formName" value={FormSubmissionNames.AddValue} />
        <div className="row">
          <label htmlFor="value">Value: </label>
          <input ref={valueInputRef} type="number" id="value" name="value" step={1} required defaultValue={0} />
        </div>
        <div className="row">
          <button ref={submitButtonRef} type="submit">Submit</button>
          <button type="button" onClick={setRandom}>Set to vandom value</button>
        </div>
      </Form>
      <h1>Click the button to process</h1>
      <Form method="post" className="processingForm">
        <input type="hidden" name="formName" value={FormSubmissionNames.ProcessValues} />
        <button type="submit">Submit</button>
      </Form>
      <div className="columns">
        <div>
          <h1>Items ({items.length}):</h1>
          <div className="items">
            <div className="header">ID</div>
            <div className="header">Value</div>
            <div className="header">Created At</div>
            <div className="header">Updated At</div>
            {items.length === 0
              ? <div className="empty">No Items</div>
              : items.map(item => {
                return <React.Fragment key={item.id}>
                  <div>{item.id}</div>
                  <div><b>{item.value}</b></div>
                  <div>{dateFormatter.format(new Date(item.createdAt))}</div>
                  <div>{dateFormatter.format(new Date(item.updatedAt))}</div>
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
            <div className="header">Updated At</div>
            {results.length === 0
              ? <div className="empty">No Items</div>
              : results.map(result => {
                return <React.Fragment key={result.id}>
                  <div>{result.id}</div>
                  <div><b>{result.value}</b></div>
                  <div>{dateFormatter.format(new Date(result.createdAt))}</div>
                  <div>{dateFormatter.format(new Date(result.updatedAt))}</div>
                </React.Fragment>
              })}
          </div>
        </div>
      </div>
    </>
  )
}
