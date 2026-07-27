# Kafka Client Configuration Examples

## 📌 Java Spring Boot

### application.yml
```yaml
spring:
  kafka:
    bootstrap-servers: kafka:29094
    properties:
      security.protocol: SASL_SSL
      sasl.mechanism: SCRAM-SHA-256
      sasl.jaas.config: "org.apache.kafka.common.security.scram.ScramLoginModule required username=\"${kafka.client.username}\" password=\"${kafka.client.password}\";"
      ssl.truststore.location: ${KAFKA_TRUSTSTORE_LOCATION}
      ssl.truststore.password: ${KAFKA_TRUSTSTORE_PASSWORD}
      ssl.truststore.type: PKCS12
      ssl.endpoint.identification.algorithm: HTTPS
    
    producer:
      key-serializer: org.apache.kafka.common.serialization.StringSerializer
      value-serializer: org.apache.kafka.common.serialization.StringSerializer
      acks: all
      retries: 3
    
    consumer:
      key-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      value-deserializer: org.apache.kafka.common.serialization.StringDeserializer
      group-id: my-app
      auto-offset-reset: earliest
      enable-auto-commit: false

# Credentials from environment
kafka:
  client:
    username: ${KAFKA_CLIENT_USERNAME:client}
    password: ${KAFKA_CLIENT_PASSWORD}
```

### application.properties
```properties
# Kafka broker
spring.kafka.bootstrap-servers=kafka:29094

# Security
spring.kafka.properties.security.protocol=SASL_SSL
spring.kafka.properties.sasl.mechanism=SCRAM-SHA-256
spring.kafka.properties.sasl.jaas.config=org.apache.kafka.common.security.scram.ScramLoginModule required username="${kafka.client.username}" password="${kafka.client.password}";

# SSL/TLS
spring.kafka.properties.ssl.truststore.location=${KAFKA_TRUSTSTORE_LOCATION}
spring.kafka.properties.ssl.truststore.password=${KAFKA_TRUSTSTORE_PASSWORD}
spring.kafka.properties.ssl.truststore.type=PKCS12
spring.kafka.properties.ssl.endpoint.identification.algorithm=HTTPS

# Producer
spring.kafka.producer.key-serializer=org.apache.kafka.common.serialization.StringSerializer
spring.kafka.producer.value-serializer=org.apache.kafka.common.serialization.StringSerializer
spring.kafka.producer.acks=all
spring.kafka.producer.retries=3

# Consumer
spring.kafka.consumer.key-deserializer=org.apache.kafka.common.serialization.StringDeserializer
spring.kafka.consumer.value-deserializer=org.apache.kafka.common.serialization.StringDeserializer
spring.kafka.consumer.group-id=my-app
spring.kafka.consumer.auto-offset-reset=earliest
spring.kafka.consumer.enable-auto-commit=false

# Application credentials
kafka.client.username=${KAFKA_CLIENT_USERNAME:client}
kafka.client.password=${KAFKA_CLIENT_PASSWORD}
```

### Dockerfile
```dockerfile
FROM openjdk:17-slim

WORKDIR /app

COPY target/app.jar app.jar

# Copy truststore if needed for development
COPY secrets/kafka.truststore.p12 /app/secrets/kafka.truststore.p12

ENV KAFKA_TRUSTSTORE_LOCATION=/app/secrets/kafka.truststore.p12
ENV KAFKA_TRUSTSTORE_PASSWORD=${KEYSTORE_PASSWORD}
ENV KAFKA_CLIENT_USERNAME=client
ENV KAFKA_CLIENT_PASSWORD=${KAFKA_CLIENT_PASSWORD}

EXPOSE 8080

ENTRYPOINT ["java", "-jar", "app.jar"]
```

## 🐍 Python (confluent-kafka)

### client_config.py
```python
import os

KAFKA_CONFIG = {
    'bootstrap.servers': os.getenv('KAFKA_BOOTSTRAP_SERVERS', 'kafka:29094'),
    'security.protocol': 'SASL_SSL',
    'sasl.mechanism': 'SCRAM-SHA-256',
    'sasl.username': os.getenv('KAFKA_CLIENT_USERNAME', 'client'),
    'sasl.password': os.getenv('KAFKA_CLIENT_PASSWORD'),
    'ssl.ca.location': os.getenv('KAFKA_CA_CERT_LOCATION', 'secrets/ca-cert.pem'),
    'ssl.certificate.location': os.getenv('KAFKA_CLIENT_CERT_LOCATION', 'secrets/client-cert.pem'),
    'ssl.key.location': os.getenv('KAFKA_CLIENT_KEY_LOCATION', 'secrets/client-key.pem'),
    'ssl.endpoint.identification.algorithm': 'https',
    'group.id': os.getenv('KAFKA_GROUP_ID', 'python-app'),
    'auto.offset.reset': 'earliest',
    'enable.auto.commit': False,
}

# For production, disable certificate verification only if necessary
if os.getenv('KAFKA_SKIP_SSL_VERIFY', 'false').lower() == 'true':
    KAFKA_CONFIG['ssl.endpoint.identification.algorithm'] = 'none'
```

### producer.py
```python
from confluent_kafka import Producer
import json
from client_config import KAFKA_CONFIG

producer = Producer(KAFKA_CONFIG)

def delivery_report(err, msg):
    if err is not None:
        print(f'Message delivery failed: {err}')
    else:
        print(f'Message delivered to {msg.topic()} [{msg.partition()}]')

topic = 'my-topic'
message = {'event': 'test', 'timestamp': '2024-07-27'}

producer.produce(
    topic,
    key='key1',
    value=json.dumps(message),
    callback=delivery_report
)

producer.flush()
```

### consumer.py
```python
from confluent_kafka import Consumer
import json
from client_config import KAFKA_CONFIG

config = KAFKA_CONFIG.copy()
config['group.id'] = 'python-consumer-group'

consumer = Consumer(config)
consumer.subscribe(['my-topic'])

try:
    while True:
        msg = consumer.poll(timeout=1.0)
        if msg is None:
            continue
        
        if msg.error():
            print(f'Error: {msg.error()}')
            continue
        
        value = json.loads(msg.value().decode('utf-8'))
        print(f'Received: {value}')
        
except KeyboardInterrupt:
    pass
finally:
    consumer.close()
```

## 🟩 Node.js (kafkajs)

### kafka-config.js
```javascript
const { Kafka, logLevel } = require('kafkajs');
const fs = require('fs');
const path = require('path');

const kafka = new Kafka({
  clientId: 'node-app',
  brokers: [process.env.KAFKA_BOOTSTRAP_SERVERS || 'kafka:29094'],
  ssl: {
    rejectUnauthorized: true,
    ca: [fs.readFileSync(path.join(__dirname, 'secrets/ca-cert.pem'), 'utf-8')],
    cert: fs.readFileSync(path.join(__dirname, 'secrets/client-cert.pem'), 'utf-8'),
    key: fs.readFileSync(path.join(__dirname, 'secrets/client-key.pem'), 'utf-8'),
  },
  sasl: {
    mechanism: 'scram-sha-256',
    username: process.env.KAFKA_CLIENT_USERNAME || 'client',
    password: process.env.KAFKA_CLIENT_PASSWORD,
  },
  logLevel: logLevel.ERROR,
  retry: {
    initialRetryTime: 100,
    retries: 8,
  },
});

module.exports = kafka;
```

### producer.js
```javascript
const kafka = require('./kafka-config');

async function produceMessage() {
  const producer = kafka.producer();
  
  await producer.connect();
  
  const result = await producer.send({
    topic: 'my-topic',
    messages: [
      { key: 'key1', value: JSON.stringify({ event: 'test' }) },
    ],
  });
  
  console.log('Message sent:', result);
  await producer.disconnect();
}

produceMessage().catch(console.error);
```

### consumer.js
```javascript
const kafka = require('./kafka-config');

async function consumeMessages() {
  const consumer = kafka.consumer({ groupId: 'node-consumer-group' });
  
  await consumer.connect();
  await consumer.subscribe({ topic: 'my-topic', fromBeginning: true });
  
  await consumer.run({
    eachMessage: async ({ topic, partition, message }) => {
      console.log({
        partition,
        offset: message.offset,
        key: message.key.toString(),
        value: message.value.toString(),
      });
    },
  });
}

consumeMessages().catch(console.error);
```

## 🔧 Go (confluent-kafka-go)

### kafka-config.go
```go
package main

import (
	"fmt"
	"os"

	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
)

func getKafkaConfig() kafka.ConfigMap {
	config := kafka.ConfigMap{
		"bootstrap.servers":                   getEnv("KAFKA_BOOTSTRAP_SERVERS", "kafka:29094"),
		"security.protocol":                   "SASL_SSL",
		"sasl.mechanism":                      "SCRAM-SHA-256",
		"sasl.username":                       getEnv("KAFKA_CLIENT_USERNAME", "client"),
		"sasl.password":                       os.Getenv("KAFKA_CLIENT_PASSWORD"),
		"ssl.ca.location":                     getEnv("KAFKA_CA_CERT", "secrets/ca-cert.pem"),
		"ssl.certificate.location":            getEnv("KAFKA_CLIENT_CERT", "secrets/client-cert.pem"),
		"ssl.key.location":                    getEnv("KAFKA_CLIENT_KEY", "secrets/client-key.pem"),
		"ssl.endpoint.identification.algorithm": "https",
	}
	return config
}

func getEnv(key, defaultValue string) string {
	if value := os.Getenv(key); value != "" {
		return value
	}
	return defaultValue
}
```

### producer.go
```go
package main

import (
	"fmt"

	"github.com/confluentinc/confluent-kafka-go/v2/kafka"
)

func produceMessage() error {
	config := getKafkaConfig()
	config["client.id"] = "go-producer"

	producer, err := kafka.NewProducer(&config)
	if err != nil {
		return err
	}
	defer producer.Close()

	topic := "my-topic"
	message := &kafka.Message{
		TopicPartition: kafka.TopicPartition{
			Topic:     &topic,
			Partition: kafka.PartitionAny,
		},
		Key:   []byte("key1"),
		Value: []byte(`{"event": "test"}`),
	}

	deliveryChan := make(chan kafka.Event)
	producer.Produce(message, deliveryChan)

	e := <-deliveryChan
	m := e.(*kafka.Message)

	if m.TopicPartition.Error != nil {
		return fmt.Errorf("delivery failed: %v", m.TopicPartition.Error)
	}

	fmt.Printf("Message delivered to partition %d, offset %d\n",
		m.TopicPartition.Partition, m.TopicPartition.Offset)

	return nil
}
```

## 📋 Docker Compose Override for Client Services

### docker-compose.client.yml
```yaml
version: '3.9'

services:
  my-app:
    image: my-app:latest
    environment:
      KAFKA_BOOTSTRAP_SERVERS: kafka:29094
      KAFKA_CLIENT_USERNAME: client
      KAFKA_CLIENT_PASSWORD: ${KAFKA_CLIENT_PASSWORD}
      KAFKA_TRUSTSTORE_LOCATION: /app/secrets/kafka.truststore.p12
      KAFKA_TRUSTSTORE_PASSWORD: ${KEYSTORE_PASSWORD}
    volumes:
      - ./secrets/kafka.truststore.p12:/app/secrets/kafka.truststore.p12:ro
      - ./secrets/ca-cert.pem:/app/secrets/ca-cert.pem:ro
    depends_on:
      - kafka
    networks:
      - kafka-network

networks:
  kafka-network:
    external: true
```

Run with:
```bash
docker-compose -f compose.yaml -f docker-compose.client.yml up
```
