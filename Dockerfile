# Образ приложения в один этап — отправная точка домашнего задания.
# <базовый образ> заменить базовым образом своего варианта.
# В таком виде сборка падает: драйверы баз компилируются из исходников,
# а компилятора и заголовков в образе нет. Задание — переписать файл в два этапа.
FROM python:3.11-slim AS build

RUN python -m venv /venv
RUN apt-get update && apt-get install -y --no-install-recommends \
    gcc \
    libc6-dev \
    libpq-dev \
    default-libmysqlclient-dev \
    pkg-config \
    && rm -rf /var/lib/apt/lists/*

COPY requirements.txt .
RUN /venv/bin/pip install --no-cache-dir -r requirements.txt

FROM python:3.11-slim

RUN apt-get update && apt-get install -y --no-install-recommends \
    libpq5 \
    libmariadb3 \
    && rm -rf /var/lib/apt/lists/*

COPY --from=build /venv /venv
ENV PATH=/venv/bin:$PATH

WORKDIR /app
COPY app.py .

ARG VERSION=5.0
RUN echo "$VERSION" > /app/VERSION

ENV PYTHONDONTWRITEBYTECODE=1
STOPSIGNAL SIGINT
CMD ["python", "app.py"]
