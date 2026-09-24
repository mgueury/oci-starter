FROM ghcr.io/astral-sh/uv:latest AS uv

FROM python:3-bookworm

COPY --from=uv /uv /uvx /bin/

ENV APP_CONFIG_FILE=/tmp/config.json \
    PYTHONDONTWRITEBYTECODE=1 \
    PYTHONUNBUFFERED=1

WORKDIR /app
COPY requirements.txt ./
RUN uv pip install --system -r requirements.txt

COPY ./ /app/

EXPOSE 8080

ENTRYPOINT ["python3","rest.py"]