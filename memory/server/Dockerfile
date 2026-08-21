FROM python:3.12-slim

# libpq for psycopg[binary]'s runtime, curl for the container healthcheck.
RUN apt-get update \
    && apt-get install -y --no-install-recommends libpq5 curl \
    && rm -rf /var/lib/apt/lists/*

WORKDIR /app
RUN pip install --no-cache-dir mem0ai==2.0.18 fastapi==0.121.2 uvicorn==0.38.0 "psycopg[binary]==3.2.4"

COPY app.py .

CMD ["uvicorn", "app:app", "--host", "0.0.0.0", "--port", "8000"]
