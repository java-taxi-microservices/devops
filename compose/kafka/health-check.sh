#!/bin/bash

# Kafka Health Check and Verification Script
# This script verifies that Kafka is properly configured and running

set -e

echo "🔍 Kafka Health Check"
echo "===================="

# Colors for output
GREEN='\033[0;32m'
RED='\033[0;31m'
YELLOW='\033[1;33m'
NC='\033[0m' # No Color

# Check if Docker containers are running
echo -e "\n📦 Checking Docker containers..."
if docker ps | grep -q kafka; then
    echo -e "${GREEN}✓${NC} Kafka container is running"
else
    echo -e "${RED}✗${NC} Kafka container is NOT running"
    echo "   Start with: docker-compose up -d"
    exit 1
fi

if docker ps | grep -q kafka-ui; then
    echo -e "${GREEN}✓${NC} Kafka UI container is running"
else
    echo -e "${RED}✗${NC} Kafka UI container is NOT running"
    echo "   Start with: docker-compose up -d"
    exit 1
fi

# Check if Kafka is healthy
echo -e "\n🏥 Checking Kafka health..."
HEALTH=$(docker inspect --format='{{.State.Health.Status}}' kafka 2>/dev/null || echo "unknown")
if [ "$HEALTH" = "healthy" ]; then
    echo -e "${GREEN}✓${NC} Kafka health check passed"
elif [ "$HEALTH" = "starting" ]; then
    echo -e "${YELLOW}⟳${NC} Kafka is starting... please wait"
else
    echo -e "${RED}✗${NC} Kafka health check failed"
    echo "   Check logs: docker logs kafka"
fi

# Check if ports are listening
echo -e "\n🔌 Checking ports..."
if docker exec kafka ss -tlnp 2>/dev/null | grep -q 29092; then
    echo -e "${GREEN}✓${NC} Port 29092 (PLAINTEXT) is listening"
else
    echo -e "${RED}✗${NC} Port 29092 (PLAINTEXT) is NOT listening"
fi

if docker exec kafka ss -tlnp 2>/dev/null | grep -q 29093; then
    echo -e "${GREEN}✓${NC} Port 29093 (CONTROLLER) is listening"
else
    echo -e "${RED}✗${NC} Port 29093 (CONTROLLER) is NOT listening"
fi

if docker exec kafka ss -tlnp 2>/dev/null | grep -q 29094; then
    echo -e "${GREEN}✓${NC} Port 29094 (SASL_SSL) is listening"
else
    echo -e "${RED}✗${NC} Port 29094 (SASL_SSL) is NOT listening"
fi

# Check certificates
echo -e "\n🔐 Checking certificates..."
SECRETS_DIR="./secrets"
if [ -f "$SECRETS_DIR/kafka.server.keystore.p12" ]; then
    echo -e "${GREEN}✓${NC} Server keystore exists"
else
    echo -e "${RED}✗${NC} Server keystore NOT found"
fi

if [ -f "$SECRETS_DIR/kafka.truststore.p12" ]; then
    echo -e "${GREEN}✓${NC} Truststore exists"
else
    echo -e "${RED}✗${NC} Truststore NOT found"
fi

if [ -f "$SECRETS_DIR/ca-cert.pem" ]; then
    echo -e "${GREEN}✓${NC} CA certificate exists"
else
    echo -e "${RED}✗${NC} CA certificate NOT found"
fi

# Check environment variables
echo -e "\n🔑 Checking environment variables..."
if [ -f ".env" ]; then
    echo -e "${GREEN}✓${NC} .env file exists"
    
    if grep -q "KAFKA_ADMIN_PASSWORD=" .env; then
        echo -e "${GREEN}✓${NC} KAFKA_ADMIN_PASSWORD is set"
    else
        echo -e "${RED}✗${NC} KAFKA_ADMIN_PASSWORD is NOT set"
    fi
    
    if grep -q "KEYSTORE_PASSWORD=" .env; then
        echo -e "${GREEN}✓${NC} KEYSTORE_PASSWORD is set"
    else
        echo -e "${RED}✗${NC} KEYSTORE_PASSWORD is NOT set"
    fi
else
    echo -e "${RED}✗${NC} .env file NOT found"
    echo "   Copy from: cp .env.example .env"
fi

# Test PLAINTEXT connection (for debugging)
echo -e "\n🧪 Testing PLAINTEXT connection..."
if docker exec kafka timeout 5 kafka-topics.sh --bootstrap-server kafka:29092 --list >/dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} PLAINTEXT connection successful"
else
    echo -e "${YELLOW}⟳${NC} PLAINTEXT connection test inconclusive"
fi

# List topics
echo -e "\n📚 Available topics..."
docker exec kafka kafka-topics.sh --bootstrap-server kafka:29092 --list 2>/dev/null || echo "   (No topics yet)"

# Check if Kafka UI is accessible
echo -e "\n🌐 Checking Kafka UI..."
if curl -s http://localhost:8280 > /dev/null 2>&1; then
    echo -e "${GREEN}✓${NC} Kafka UI is accessible at http://localhost:8280"
else
    echo -e "${YELLOW}⟳${NC} Kafka UI may not be ready yet (try again in a few seconds)"
fi

echo -e "\n✅ Health check complete!"
echo -e "\n📖 Documentation:"
echo "   - Setup guide: KAFKA_SETUP.md"
echo "   - Client examples: CLIENT_EXAMPLES.md"
echo "   - Quick start: README.md"
