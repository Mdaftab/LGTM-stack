FROM python:3.11-slim

WORKDIR /app
COPY app.py /app/app.py
RUN pip install --no-cache-dir prometheus-client requests

ENV METRICS_PORT=8000
EXPOSE 8000 8080

CMD ["python", "app.py"]

