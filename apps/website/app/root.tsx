import type { LinksFunction, MetaFunction } from "@remix-run/node"
import {
  Links,
  LiveReload,
  Meta,
  Outlet,
  Scripts,
  ScrollRestoration
} from "@remix-run/react"
import resetStyles from "~/styles/reset.css"
import rootStyles from "~/styles/root.css"

export const links: LinksFunction = () => [
  { rel: "stylesheet", href: resetStyles },
  { rel: "stylesheet", href: rootStyles },
]

export const meta: MetaFunction = () => ({
  charset: "utf-8",
  title: "Batch Processor Test",
  viewport: "width=device-width,initial-scale=1",
})

export default function App() {
  return (
    <html lang="en">
      <head>
        <Meta />
        <Links />
      </head>
      <body>
        <header>
          <h1>Batch Processsor Test</h1>
          <p>Application to test container scaling and background processing of data</p>
        </header>
        <main>
          <Outlet />
        </main>
        <footer>
          <ul>
            <li><a href="https://azure.microsoft.com/en-us/products/container-apps/" target="_blank">Azure Container Apps</a></li>
          </ul>
        </footer>
        <ScrollRestoration />
        <Scripts />
        <LiveReload />
      </body>
    </html>
  )
}
