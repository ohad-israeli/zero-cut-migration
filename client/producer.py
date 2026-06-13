#!/usr/bin/env python3
"""Continuous demo producer for the zero-cut migration.

Sends a monotonically increasing sequence number to the demo topic, forever, at a
steady rate. Point BOOTSTRAP at the CPC Gateway endpoint (NOT the broker) and leave
it running across the cutover: it should never need a restart and should never error,
because the Gateway keeps the same client-facing endpoint before, during (briefly
fenced), and after the switch to Confluent Cloud.

The client always speaks PLAINTEXT with no auth to the Gateway — the Gateway swaps in
the Confluent Cloud SASL/SSL credentials on the back side. That's the point: clients
don't learn new endpoints or credentials.
"""
import json
import os
import sys
import time

from confluent_kafka import Producer

BOOTSTRAP = os.environ.get("BOOTSTRAP", "localhost:9595")
TOPIC = os.environ.get("DEMO_TOPIC", "orders")
RATE_HZ = float(os.environ.get("RATE_HZ", "4"))  # messages per second


def main() -> None:
    producer = Producer(
        {
            "bootstrap.servers": BOOTSTRAP,
            # Survive the brief fence window during cutover without dying.
            "retries": 2147483647,
            "retry.backoff.ms": 250,
            "delivery.timeout.ms": 600000,
            "reconnect.backoff.max.ms": 5000,
            "enable.idempotence": True,
        }
    )
    print(f"producing to topic={TOPIC} via bootstrap={BOOTSTRAP} at {RATE_HZ}/s", flush=True)

    seq = 0
    interval = 1.0 / RATE_HZ

    def on_delivery(err, msg):
        if err is not None:
            print(f"  ! delivery failed seq={msg.key().decode()}: {err}", flush=True)

    while True:
        payload = {"seq": seq, "ts": time.time()}
        producer.produce(
            TOPIC,
            key=str(seq).encode(),
            value=json.dumps(payload).encode(),
            on_delivery=on_delivery,
        )
        producer.poll(0)
        if seq % 20 == 0:
            print(f"  -> sent seq={seq}", flush=True)
        seq += 1
        time.sleep(interval)


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nstopped", file=sys.stderr)
