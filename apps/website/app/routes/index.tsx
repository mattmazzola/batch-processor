import { DataFunctionArgs, LinksFunction } from "@remix-run/node"
import { Form } from "@remix-run/react"
import indexStyles from "~/styles/index.css"

export const links: LinksFunction = () => [
  { rel: "stylesheet", href: indexStyles },
]

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
  return (
    <>
      <Form method="post" className="addValueForm">
        <h1>Enter a value:</h1>
        <input type="hidden" name="formName" value={FormSubmissionNames.AddValue} />
        <div>
          <label htmlFor="value">Value: </label>
          <input type="number" id="value" name="value" step={1} required />
        </div>
        <button type="submit">Submit</button>
      </Form>
      <Form method="post" className="processingForm">
        <input type="hidden" name="formName" value={FormSubmissionNames.ProcessValues} />
        <h1>Click the button to process</h1>
        <button type="submit">Submit</button>
      </Form>
    </>
  )
}
