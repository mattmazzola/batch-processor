import { PrismaClient } from "@prisma/client"

const db = new PrismaClient()

const items = await db.item.findMany()
const values = items.map(i => i.value)
const total = values.reduce((sum, value) => sum + value, 0)

console.log(`Add up values: `, values)

const savedResult = await db.result.create({
    data: {
        value: total
    }
})

console.log(`Saved sum: `, { savedResult })