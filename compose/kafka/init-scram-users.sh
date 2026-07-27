#!/bin/bash

# This script creates SCRAM users in Kafka
# It should be run AFTER Kafka is fully started
# Usage: ./init-scram-users.sh

BOOTSTRAP_SERVER="${BOOTSTRAP_SERVER:-localhost:29092}"
KAFKA_ADMIN_PASSWORD="${KAFKA_ADMIN_PASSWORD:-admin-secure-password-change-me}"
KAFKA_CLIENT_PASSWORD="${KAFKA_CLIENT_PASSWORD:-client-secure-password-change-me}"

echo "🔐 Initializing Kafka SCRAM users..."
echo "📌 Bootstrap Server: $BOOTSTRAP_SERVER"

# Wait for Kafka to be ready
echo "⏳ Waiting for Kafka to be ready..."
for i in {1..30}; do
  if kafka-topics.sh --bootstrap-server "$BOOTSTRAP_SERVER" --list >/dev/null 2>&1; then
    echo "✅ Kafka is ready!"
    break
  fi
  echo "   Attempt $i/30... waiting..."
  sleep 2
done

# Create SCRAM admin user
echo "📌 Creating admin user..."
kafka-user-scram.sh \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --create \
  --entity-type users \
  --entity-name admin \
  --new-mechanism SCRAM-SHA-256 \
  --new-password "$KAFKA_ADMIN_PASSWORD" 2>/dev/null || echo "   Admin user already exists or creation skipped"

# Create SCRAM client user
echo "📌 Creating client user..."
kafka-user-scram.sh \
  --bootstrap-server "$BOOTSTRAP_SERVER" \
  --create \
  --entity-type users \
  --entity-name client \
  --new-mechanism SCRAM-SHA-256 \
  --new-password "$KAFKA_CLIENT_PASSWORD" 2>/dev/null || echo "   Client user already exists or creation skipped"

echo "✅ SCRAM users initialized!"
