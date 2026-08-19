#!/bin/sh

set -eu

NATS_BOX_IMAGE="${NATS_BOX_IMAGE:-natsio/nats-box:0.19.7}"
NATS_URL="${NATS_URL:-nats://host.docker.internal:4222}"

nats_cli() {
  docker run --rm \
    --add-host=host.docker.internal:host-gateway \
    --env NATS_URL="$NATS_URL" \
    "$NATS_BOX_IMAGE" \
    nats "$@"
}

ensure_stream() {
  name="$1"
  subjects="$2"
  description="$3"

  if nats_cli stream info "$name" --json >/dev/null 2>&1; then
    printf 'stream %-15s already exists\n' "$name"
    return
  fi

  # Subject values are comma-separated because the nats CLI accepts a list in
  # this form without opening an interactive prompt.
  nats_cli stream add "$name" \
    --subjects "$subjects" \
    --description "$description" \
    --storage memory \
    --retention limits \
    --discard old \
    --max-age 24h \
    --replicas 1 \
    --defaults >/dev/null
  printf 'stream %-15s created\n' "$name"
}

ensure_consumer() {
  stream="$1"
  name="$2"
  filter="$3"
  description="$4"

  if nats_cli consumer info "$stream" "$name" --json >/dev/null 2>&1; then
    printf 'consumer %-15s/%s already exists\n' "$stream" "$name"
    return
  fi

  nats_cli consumer add "$stream" "$name" \
    --description "$description" \
    --pull \
    --ack explicit \
    --deliver all \
    --replay instant \
    --filter "$filter" \
    --max-deliver 5 \
    --defaults >/dev/null
  printf 'consumer %-15s/%s created\n' "$stream" "$name"
}

if ! command -v docker >/dev/null 2>&1; then
  printf 'docker is required to run the NATS topology fixture\n' >&2
  exit 1
fi

printf 'Seeding EventAtlas topology at %s\n' "$NATS_URL"

ensure_stream \
  "ORDERS" \
  "orders.created,orders.updated,orders.cancelled" \
  "Order lifecycle events"
ensure_consumer "ORDERS" "billing-worker" "orders.created" "Creates invoices for new orders"
ensure_consumer "ORDERS" "fulfillment-worker" "orders.*" "Coordinates order fulfillment"
ensure_consumer "ORDERS" "orders-audit" "orders.>" "Retains an audit view of order events"

ensure_stream \
  "PAYMENTS" \
  "payments.authorized,payments.failed,payments.refunded" \
  "Payment lifecycle events"
ensure_consumer "PAYMENTS" "ledger-projector" "payments.>" "Projects payment events into the ledger"
ensure_consumer "PAYMENTS" "fraud-detector" "payments.authorized" "Evaluates authorized payments"

ensure_stream \
  "INVENTORY" \
  "inventory.reserved,inventory.released,inventory.low" \
  "Inventory availability events"
ensure_consumer "INVENTORY" "stock-projector" "inventory.>" "Maintains the stock read model"
ensure_consumer "INVENTORY" "reorder-worker" "inventory.low" "Triggers replenishment workflows"

ensure_stream \
  "NOTIFICATIONS" \
  "notifications.email,notifications.sms,notifications.push" \
  "Outbound notification commands"
ensure_consumer "NOTIFICATIONS" "email-dispatcher" "notifications.email" "Dispatches email notifications"
ensure_consumer "NOTIFICATIONS" "mobile-dispatcher" "notifications.*" "Dispatches mobile notifications"

printf '\nFixture ready. JetStream now contains:\n'
nats_cli stream list
