# eventatlas-deploy

[![Deploy Assets CI](https://github.com/lucacox/eventatlas-deploy/actions/workflows/ci.yml/badge.svg?branch=main)](https://github.com/lucacox/eventatlas-deploy/actions/workflows/ci.yml)

Runtime and local development assets for EventAtlas.

## Local development stack

The Compose environment runs the complete local stack: NATS with JetStream,
PostgreSQL, the Go backend with Air live reload, and the Vite development
server with React HMR.

Keep these repositories next to each other using the default directory names:

```text
eventatlas/
eventatlas-deploy/
eventatlas-web/
```

Then start the stack from `eventatlas-deploy`:

```sh
docker compose up --build
```

The services are exposed as:

| Service | Address |
| --- | --- |
| Web application | `http://127.0.0.1:5173` |
| Backend API | `http://127.0.0.1:8080/api/v1/topology` |
| API documentation | `http://127.0.0.1:8080/docs` |
| NATS | `nats://127.0.0.1:4222` |
| NATS monitoring | `http://127.0.0.1:8222` |
| PostgreSQL | `postgres://eventatlas:eventatlas@127.0.0.1:5432/eventatlas` |

Changes under `eventatlas` trigger an Air rebuild and restart. Changes under
`eventatlas-web` are picked up by Vite and sent to the browser through HMR.
The backend refreshes its NATS topology every five seconds in this environment.
Dependencies are cached in named Docker volumes so source bind mounts do not
reuse host `node_modules` or Go build caches.

To keep using another directory layout, provide absolute or Compose-relative
build contexts:

```sh
EVENTATLAS_BACKEND_CONTEXT=/path/to/eventatlas \
EVENTATLAS_WEB_CONTEXT=/path/to/eventatlas-web \
docker compose up --build
```

To run only the infrastructure while developing the applications directly on
the host:

```sh
docker compose up -d nats postgres
```

Follow only the application logs with:

```sh
docker compose logs -f backend web
```

The credentials above are local-development defaults and must not be reused in
a shared environment.

Stop the containers without deleting their data:

```sh
docker compose stop
```

Deleting the Compose volumes also deletes the local broker and topology data.

## Seed a visual NATS topology

The fixture creates four JetStream streams, twelve subjects and nine durable
consumers. It is safe to run repeatedly: existing fixture resources are left
untouched and missing resources are created.

Docker must be running and NATS with JetStream must be exposed on port `4222`.
Both the complete stack and the infrastructure-only command above satisfy these
requirements.

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
