# eventatlas-deploy

Runtime and local development assets for EventAtlas.

## Seed a visual NATS topology

The fixture creates four JetStream streams, twelve subjects and nine durable
consumers. It is safe to run repeatedly: existing fixture resources are left
untouched and missing resources are created.

Docker must be running and NATS with JetStream must be exposed on port `4222`.

```sh
./scripts/seed-nats-topology.sh
```

To target another NATS endpoint or nats-box release:

```sh
NATS_URL=nats://host.docker.internal:4223 \
NATS_BOX_IMAGE=natsio/nats-box:0.19.7 \
./scripts/seed-nats-topology.sh
```

The image contains the official NATS CLI, so no host installation is required.
