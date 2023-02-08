import asyncio
import json
import os

from azure.storage.queue import QueueClient
from dotenv import load_dotenv
from prisma import Prisma

load_dotenv()

async def main() -> None:
    print(f'Validate environment variables...')

    DATABASE_URL = os.getenv("DATABASE_URL")
    if DATABASE_URL is None:
        raise Exception(f'You attempted to run the container without providing the DATABASE_URL')

    STORAGE_CONNECTION_STRING = os.getenv("STORAGE_CONNECTION_STRING")
    if STORAGE_CONNECTION_STRING is None:
        raise Exception(f'You attempted to run the container without providing the STORAGE_CONNECTION_STRING')

    STORAGE_QUEUE_NAME = os.getenv("STORAGE_QUEUE_NAME")
    if STORAGE_CONNECTION_STRING is None:
        raise Exception(f'You attempted to run the container without providing the STORAGE_QUEUE_NAME')

    assert STORAGE_QUEUE_NAME is not None

    queue_client = QueueClient.from_connection_string(STORAGE_CONNECTION_STRING, STORAGE_QUEUE_NAME)
    print(f'Client created for: {STORAGE_QUEUE_NAME}')

    messages = queue_client.receive_messages()

    db: Prisma | None = None
    number_value = 0
    string_value = '?'

    for message in messages:
        print(f'Dequeueing message: {message.content}')
        queue_client.delete_message(message.id, message.pop_receipt)
        if message.content is not None:
            message_content_json = json.loads(message.content)
            number_value = message_content_json['input']['numberValue']
            string_value = message_content_json['input']['stringValue']

        db = Prisma()
        await db.connect()
        print(f'Connected to database')

        print(f'Fetch items from database...')
        items = await db.item.find_many()
        values = [i.value for i in items]
        print(f'Add up {len(values)} values: {values}')

        total = sum(values)

        saved_result = await db.result.create(data={
            'value': total,
            'message': f"Number: {number_value} String: {string_value} from Python Storage Queue Processor"
        })

        print(f'Saved sum: {saved_result.value}')

    if db is not None:
        await db.disconnect()

    exit(0)

if __name__ == '__main__':
    asyncio.run(main())
