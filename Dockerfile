# ==========================================
# STAGE 1: BUILDER
# ==========================================
FROM python:3.14-slim-bookworm as builder

RUN apt-get update && apt-get install -y --no-install-recommends \
    build-essential \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# ... (Same Poetry setup as above) ...
ENV POETRY_HOME="/opt/poetry" \
    POETRY_VIRTUALENVS_IN_PROJECT=true \
    POETRY_NO_INTERACTION=1
ENV PATH="$POETRY_HOME/bin:$PATH"
RUN pip install poetry

WORKDIR /app
COPY pyproject.toml poetry.lock ./
RUN --mount=type=cache,target=/root/.cache/pypoetry \
    poetry install --no-root --only main

COPY . .
# Note: In a real production build, you might run 'collectstatic' here
# if you are serving static files via Nginx/WhiteNoise.

# ==========================================
# STAGE 2: RUNTIME
# ==========================================
FROM python:3.11-slim-bookworm as runtime

# Install ONLY runtime libraries for Postgres (no gcc/compiler)
RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    && rm -rf /var/lib/apt/lists/*

RUN groupadd -g 1000 geoscale && \
    useradd -u 1000 -g geoscale -s /bin/bash -m geoscale

ENV PYTHONUNBUFFERED=1 \
    PATH="/app/.venv/bin:$PATH" \
    PYTHONPATH="/app/src"

WORKDIR /app

COPY --from=builder --chown=geoscale:geoscale /app/.venv /app/.venv
COPY --from=builder --chown=geoscale:geoscale /app/src /app/src
# Copy entrypoint script if you have one for migrations
COPY --chown=geoscale:geoscale ./entrypoint.sh /app/entrypoint.sh
RUN chmod +x /app/entrypoint.sh

USER geoscale

ENTRYPOINT ["/app/entrypoint.sh"]
CMD ["gunicorn", "src.wsgi:application", "--bind", "0.0.0.0:8000"]
