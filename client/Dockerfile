# Tiny image for the demo producer/consumer. Run it pointed at the CPC Gateway:
#   docker build -t zerocut-client ./client
#   docker run --rm -e BOOTSTRAP=<gateway-host>:9595 zerocut-client python producer.py
FROM python:3.12-slim
WORKDIR /app
COPY requirements.txt .
RUN pip install --no-cache-dir -r requirements.txt
COPY producer.py consumer.py ./
CMD ["python", "producer.py"]
