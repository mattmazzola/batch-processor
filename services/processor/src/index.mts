import { PrismaClient } from "@prisma/client"

const db = new PrismaClient()

const items = await db.item.findMany()

console.log({ items })