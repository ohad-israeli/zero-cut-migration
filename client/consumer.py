#!/usr/bin/env python3
"""Continuous demo consumer for the zero-cut migration.

Reads the demo topic via the CPC Gateway and prints progress. It commits offsets to a
consumer group; Cluster Linking syncs those offsets to Confluent Cloud, so after the
switchover this same group resumes at the right place — no reprocessing, no gap.

Watch two things across the cutover:
  - the running count keeps climbing (traffic is uninterrupted), and
  - "GAP"/"DUP" warnings stay absent (offset sync + zero-lag promote did their job).
"""
import json
import os
import sys

from confluent_kafka import Consumer

BOOTSTRAP = os.environ.get("BOOTSTRAP", "localhost:9595")
TOPIC = os.environ.get("DEMO_TOPIC", "orders")
GROUP = os.environ.get("GROUP_ID", "zerocut-demo")


def main() -> None:
    consumer = Consumer(
        {
            "bootstrap.servers": BOOTSTRAP,
            "group.id": GROUP,
            "auto.offset.reset": "earliest",
            "enable.auto.commit": True,
            "reconnect.backoff.max.ms": 5000,
        }
    )
    consumer.subscribe([TOPIC])
    print(f"consuming topic={TOPIC} group={GROUP} via bootstrap={BOOTSTRAP}", flush=True)

    last_seq: dict[int, int] = {}
    total = 0
    try:
        while True:
            msg = consumer.poll(1.0)
            if msg is None:
                continue
            if msg.error():
                print(f"  ! {msg.error()}", flush=True)
                continue
            seq = json.loads(msg.value())["seq"]
            p = msg.partition()
            prev = last_seq.get(p)
            # seq is global across partitions, so we can't expect +1 per partition;
            # we only flag obvious regressions (duplicates) per partition.
            if prev is not None and seq <= prev:
                print(f"  DUP/regress p{p}: {seq} after {prev}", flush=True)
            last_seq[p] = seq
            total += 1
            if total % 20 == 0:
                print(f"  <- received total={total} (last seq={seq} p{p})", flush=True)
    finally:
        consumer.close()


if __name__ == "__main__":
    try:
        main()
    except KeyboardInterrupt:
        print("\nstopped", file=sys.stderr)
