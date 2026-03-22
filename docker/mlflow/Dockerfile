# ─────────────────────────────────────────────
# docker/mlflow/Dockerfile
# MLflow tracking server with PostgreSQL support
# Built via GitHub Actions, pushed to ECR
# ─────────────────────────────────────────────

FROM python:3.11-slim

WORKDIR /app

# Install system dependencies
RUN apt-get update && apt-get install -y \
    gcc \
    libpq-dev \
    && rm -rf /var/lib/apt/lists/*

# Install Python packages
RUN pip install --no-cache-dir \
    mlflow==2.13.0 \
    psycopg2-binary==2.9.9 \
    boto3==1.34.0 \
    sqlalchemy==2.0.0

EXPOSE 5000

CMD ["mlflow", "server", \
     "--host", "0.0.0.0", \
     "--port", "5000", \
     "--backend-store-uri", "${MLFLOW_BACKEND_STORE_URI}", \
     "--default-artifact-root", "${MLFLOW_ARTIFACT_ROOT}", \
     "--serve-artifacts"]