import asyncio
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

    queue_client = QueueClient.from_connection_string(STORAGE_CONNECTION_STRING, STORAGE_QUEUE_NAME)
    print(f'Client created for: {STORAGE_QUEUE_NAME}')

    messages = queue_client.receive_messages()

    for message in messages:
        print(f'Dequeueing message: {message.content}')
        queue_client.delete_message(message.id, message.pop_receipt)

    prisma = Prisma()
    await prisma.connect()

    print(f'Connected to database')

    print(f'Fetch items from database...')

    await prisma.disconnect()

if __name__ == '__main__':
    asyncio.run(main())
