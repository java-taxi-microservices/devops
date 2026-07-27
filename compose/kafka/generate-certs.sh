#!/bin/bash
set -e

: "${KEYSTORE_PASSWORD:?Set KEYSTORE_PASSWORD before generating certificates}"
: "${KAFKA_ADMIN_PASSWORD:?Set KAFKA_ADMIN_PASSWORD before generating certificates}"

SECRETS_DIR="./secrets"
VALIDITY=365
KEY_SIZE=2048

echo "🔐 Generating Kafka SSL/TLS certificates..."

# Create secrets directory
mkdir -p "$SECRETS_DIR"

# 1. Generate CA (Certificate Authority)
echo "📌 Generating CA..."
openssl genrsa -out "$SECRETS_DIR/ca-key.pem" $KEY_SIZE
openssl req -new -x509 -days $VALIDITY \
  -key "$SECRETS_DIR/ca-key.pem" \
  -out "$SECRETS_DIR/ca-cert.pem" \
  -subj "/CN=kafka-ca/O=Taxi/C=UA"

# 2. Generate Server Key and Certificate (with SANs for hostname verification)
echo "📌 Generating Server certificate..."
openssl genrsa -out "$SECRETS_DIR/kafka-server-key.pem" $KEY_SIZE

# Create CSR (Certificate Signing Request)
openssl req -new \
  -key "$SECRETS_DIR/kafka-server-key.pem" \
  -out "$SECRETS_DIR/kafka-server.csr" \
  -subj "/CN=kafka/O=Taxi/C=UA"

cat > "$SECRETS_DIR/server-ext.cnf" <<EOF
subjectAltName=DNS:kafka,DNS:localhost,IP:127.0.0.1
extendedKeyUsage=serverAuth
EOF

# Sign with CA
openssl x509 -req \
  -days $VALIDITY \
  -in "$SECRETS_DIR/kafka-server.csr" \
  -CA "$SECRETS_DIR/ca-cert.pem" \
  -CAkey "$SECRETS_DIR/ca-key.pem" \
  -CAcreateserial \
  -extfile "$SECRETS_DIR/server-ext.cnf" \
  -out "$SECRETS_DIR/kafka-server-cert.pem"

# 3. Generate Client Key and Certificate
echo "📌 Generating Client certificate..."
openssl genrsa -out "$SECRETS_DIR/client-key.pem" $KEY_SIZE

openssl req -new \
  -key "$SECRETS_DIR/client-key.pem" \
  -out "$SECRETS_DIR/client.csr" \
  -subj "/CN=kafka-client/O=Taxi/C=UA"

openssl x509 -req \
  -days $VALIDITY \
  -in "$SECRETS_DIR/client.csr" \
  -CA "$SECRETS_DIR/ca-cert.pem" \
  -CAkey "$SECRETS_DIR/ca-key.pem" \
  -CAcreateserial \
  -out "$SECRETS_DIR/client-cert.pem"

# 4. Create KeyStore for Server (PKCS12)
echo "📌 Creating Server KeyStore..."
openssl pkcs12 -export \
  -in "$SECRETS_DIR/kafka-server-cert.pem" \
  -inkey "$SECRETS_DIR/kafka-server-key.pem" \
  -out "$SECRETS_DIR/kafka.server.keystore.p12" \
  -name kafka-broker \
  -passout env:KEYSTORE_PASSWORD

# 5. Create KeyStore for Client
echo "📌 Creating Client KeyStore..."
openssl pkcs12 -export \
  -in "$SECRETS_DIR/client-cert.pem" \
  -inkey "$SECRETS_DIR/client-key.pem" \
  -out "$SECRETS_DIR/kafka.client.keystore.p12" \
  -name kafka-client \
  -passout env:KEYSTORE_PASSWORD

# 6. Create TrustStore (both for server and client)
echo "📌 Creating TrustStore..."
rm -f "$SECRETS_DIR/kafka.truststore.p12"
keytool -import -alias ca-cert \
  -file "$SECRETS_DIR/ca-cert.pem" \
  -storetype PKCS12 \
  -keystore "$SECRETS_DIR/kafka.truststore.p12" \
  -storepass "$KEYSTORE_PASSWORD" \
  -noprompt

# Credential files are required by the Confluent Kafka image.
printf '%s' "$KEYSTORE_PASSWORD" > "$SECRETS_DIR/keystore_creds"
printf '%s' "$KEYSTORE_PASSWORD" > "$SECRETS_DIR/key_creds"
printf '%s' "$KEYSTORE_PASSWORD" > "$SECRETS_DIR/truststore_creds"
cat > "$SECRETS_DIR/healthcheck.properties" <<EOF
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-256
sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="admin" password="$KAFKA_ADMIN_PASSWORD";
ssl.truststore.location=/etc/kafka/secrets/kafka.truststore.p12
ssl.truststore.password=$KEYSTORE_PASSWORD
ssl.truststore.type=PKCS12
ssl.endpoint.identification.algorithm=HTTPS
EOF
cp "$SECRETS_DIR/healthcheck.properties" "$SECRETS_DIR/admin.properties"
cat > "$SECRETS_DIR/ssl.properties" <<EOF
security.protocol=SSL
ssl.truststore.location=/etc/kafka/secrets/kafka.truststore.p12
ssl.truststore.password=$KEYSTORE_PASSWORD
ssl.truststore.type=PKCS12
ssl.endpoint.identification.algorithm=HTTPS
EOF
cat > "$SECRETS_DIR/kafka_jaas.conf" <<EOF
KafkaServer {
  org.apache.kafka.common.security.scram.ScramLoginModule required
  username="admin"
  password="$KAFKA_ADMIN_PASSWORD";
};
EOF

# Set proper permissions
chmod 600 "$SECRETS_DIR"/*
chmod 644 "$SECRETS_DIR/ca-cert.pem"
chmod 644 "$SECRETS_DIR/kafka.truststore.p12"

echo "✅ Certificates generated successfully!"
echo "📂 Location: $SECRETS_DIR/"
ls -lh "$SECRETS_DIR/"
