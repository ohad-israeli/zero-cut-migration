# client/ — demo producer & consumer

A pair of long-running clients that prove the migration is *zero-cut*: point them at
the **CPC Gateway** endpoint and leave them running across the entire cutover.

```bash
docker build -t zerocut-client ./client

# Producer (steady stream of sequence numbers)
docker run --rm --name zerocut-producer \
  -e BOOTSTRAP=<gateway-host>:9595 -e DEMO_TOPIC=orders \
  zerocut-client python producer.py

# Consumer (prints running count; warns on dup/regress)
docker run --rm --name zerocut-consumer \
  -e BOOTSTRAP=<gateway-host>:9595 -e DEMO_TOPIC=orders -e GROUP_ID=zerocut-demo \
  zerocut-client python consumer.py
```

For a quick **smoke test against the raw source** (no Gateway), point `BOOTSTRAP` at
the broker's external listener (`<host>:9094`) instead of the Gateway.

| Env | Default | Meaning |
|-----|---------|---------|
| `BOOTSTRAP` | `localhost:9595` | Gateway endpoint clients connect to (never changes across cutover) |
| `DEMO_TOPIC` | `orders` | Topic to produce/consume |
| `RATE_HZ` | `4` | Producer messages/sec |
| `GROUP_ID` | `zerocut-demo` | Consumer group (offsets synced by Cluster Linking) |
