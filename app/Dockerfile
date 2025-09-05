FROM python:3.13.7-slim AS builder
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir --user -r requirements.txt

FROM python:3.13.7-slim AS production
RUN useradd --create-home --shell /bin/bash app
WORKDIR /app

COPY --from=builder /root/.local /home/app/.local
COPY . .
RUN chown -R app:app /app

USER app
ENV PATH=/home/app/.local/bin:$PATH
EXPOSE 8000

CMD ["python", "-m", "uvicorn", "main:app", "--host", "0.0.0.0", "--port", "8000"]