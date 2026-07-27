# Kafka deployment

This Compose stack runs a single-node Kafka broker with:

- TLS for broker, controller, and client connections
- SASL/SCRAM-SHA-256 authentication on the public client listener
- Automatic creation of the `admin` and `client` SCRAM users
- Kafka UI protected by a web login form

## Deploy from scratch

Requirements: Docker Engine with Compose v2, OpenSSL, and Java `keytool`.

```bash
cd compose/kafka
cp .env.example .env
chmod 600 .env
```

Edit `.env` and set unique production passwords:

```dotenv
KAFKA_ADMIN_PASSWORD=...
KAFKA_CLIENT_PASSWORD=...
KEYSTORE_PASSWORD=...
KAFKA_UI_USERNAME=admin
KAFKA_UI_PASSWORD=...
```

Generate the private TLS material and start the stack:

```bash
set -a
source .env
set +a
./generate-certs.sh
docker compose up -d
docker compose ps
```

`docker compose up` starts Kafka, waits for its TLS health check, automatically provisions both SCRAM users, and then starts Kafka UI.

Kafka UI is available at `http://localhost:8280`. Log in with `KAFKA_UI_USERNAME` and `KAFKA_UI_PASSWORD` from `.env`.

## Kafka client connection

Only port `29094` is published for clients. Use:

```text
bootstrap.servers=<server-hostname>:29094
security.protocol=SASL_SSL
sasl.mechanism=SCRAM-SHA-256
sasl.username=client
sasl.password=<KAFKA_CLIENT_PASSWORD>
ssl.truststore.location=/path/to/kafka.truststore.p12
ssl.truststore.password=<KEYSTORE_PASSWORD>
ssl.truststore.type=PKCS12
ssl.endpoint.identification.algorithm=HTTPS
```

The truststore is generated at `secrets/kafka.truststore.p12`. Copy or mount it into each client container.

## Production notes

- Keep `.env` and `secrets/` out of source control and back them up securely.
- Restrict firewall access to TCP `29094` and expose TCP `8280` only to administrators.
- Ports `29092` and `29093` are internal TLS listeners and are not published.
- This Compose file is a single-broker deployment. Use a multi-broker Kafka cluster for high availability.
- Certificate validity defaults to 365 days; rotate certificates before expiry.

## Operations

```bash
docker compose logs -f kafka
docker compose logs -f kafka-ui
./health-check.sh
docker compose restart kafka-ui
docker compose down
```

To destroy this instance, including all Kafka data:

```bash
docker compose down -v
```

The generated certificates and keystores are ignored by Git. Regenerating them changes the trust anchor, so all clients must receive the new truststore.
