# base node image
FROM node:20-alpine AS base

# Install openssl for Prisma (Alpine uses apk, not affected by Debian GPG issues)
RUN apk add --no-cache openssl

# Install all node_modules, including dev dependencies
FROM base AS deps

WORKDIR /myapp

ADD package.json ./
RUN npm install --production=false

# Setup production node_modules
FROM base AS production-deps

WORKDIR /myapp

COPY --from=deps /myapp/node_modules /myapp/node_modules
ADD package.json ./
RUN npm prune --production

# Build the app
FROM base AS build

WORKDIR /myapp

COPY --from=deps /myapp/node_modules /myapp/node_modules

ADD prisma .
RUN npx prisma generate

ADD . .
RUN npm run build

# Finally, build the production image with minimal footprint
FROM base

COPY --from=production-deps /myapp/node_modules /myapp/node_modules

COPY --from=build /myapp/node_modules/.prisma /myapp/node_modules/.prisma
COPY --from=build /myapp/build /myapp/build
COPY --from=build /myapp/package.json /myapp/package.json
COPY --from=build /myapp/start.sh /myapp/start.sh
COPY --from=build /myapp/prisma /myapp/prisma

ENV PORT="8080"
ENV NODE_ENV="production"

WORKDIR /myapp

ENTRYPOINT [ "sh", "./start.sh" ]
