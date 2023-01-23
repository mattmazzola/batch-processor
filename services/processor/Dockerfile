FROM node:16-bullseye-slim as base

RUN apt-get update && apt-get install -y openssl sqlite3

FROM base as deps

WORKDIR /myapp

ADD package.json package-lock.json /

RUN npm ci

ADD prisma .
RUN npx prisma generate

ADD . .
RUN npm run build

ENV PORT="8080"
ENV NODE_ENV="production"

ENTRYPOINT [ "npm", "start" ]