# 🚀 Kafka - Як Запустити

## 3 Кроки

### 1️⃣ Згенерувати сертифікати
```bash
./generate-certs.sh
```

### 2️⃣ Налаштувати паролі
```bash
cp .env.example .env
nano .env
# Змінити пароли на свої
```

### 3️⃣ Запустити
```bash
docker compose up -d
./health-check.sh
```

## 🌐 Доступ

- **Kafka UI:** http://localhost:8280
- **Username:** admin
- **Password:** (з .env KAFKA_ADMIN_PASSWORD)

---

## 🔗 Для Spring Boot

```yaml
spring:
  kafka:
    bootstrap-servers: kafka:29094
    properties:
      security.protocol: SASL_SSL
      sasl.mechanism: SCRAM-SHA-256
      sasl.username: admin  # або client
      sasl.password: ${KAFKA_ADMIN_PASSWORD}
      ssl.truststore.location: /path/to/secrets/kafka.truststore.p12
      ssl.truststore.password: ${KEYSTORE_PASSWORD}
      ssl.truststore.type: PKCS12
```

Див. **CLIENT_EXAMPLES.md** для інших мов.

---

## 📚 Файли

- **START_HERE.md** ← Ви тут
- **README.md** - Команди
- **CLIENT_EXAMPLES.md** - Приклади кода

