FROM python:3.11-slim AS base

RUN apt-get update && \
    apt-get install --no-install-recommends -y \
        curl \
        build-essential && \
    rm -rf /var/lib/apt/lists/*

ENV PYTHONUNBUFFERED=1 \
    PYTHONDONTWRITEBYTECODE=1 \
    POETRY_VERSION=1.3.0 \
    # make poetry install to this location
    POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1

# prepend poetry and venv to path
ENV PATH="$POETRY_HOME/bin:$PATH"

RUN curl -sSL https://install.python-poetry.org | python3 -

FROM base AS app

WORKDIR /myapp

COPY . .

RUN poetry install

COPY prisma .

RUN poetry run prisma generate

ENTRYPOINT ["sh", "./docker-entrypoint.sh"]
