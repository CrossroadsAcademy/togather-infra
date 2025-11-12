# Kafka Authentication Setup Guide

Guide for setting up Apache Kafka with SASL_SCRAM authentication and SSL/TLS encryption.

## Overview

This repository demonstrates how to set up a production-ready Kafka cluster with:

- **SSL/TLS Encryption**: All traffic encrypted
- **SCRAM-SHA-256 Authentication**: Password-based authentication for clients
- **Mutual TLS**: Certificate-based authentication for inter-broker communication
- **Multiple Listeners**: Separate ports for admin and client operations
- **KRaft Mode**: No Zookeeper required

## Prerequisites

- Docker & Docker Compose
- OpenSSL
- Basic understanding of:
  - SSL/TLS certificates
  - Kafka concepts (kraf, broker, consumers/producers)
  - Authentication mechanisms

## Quick Start

```bash

# 1. Generate SSL certificates
./generate.sh

# 2. Start Kafka

docker-compose up -d

# 3. Create SCRAM users
./setup_auth.sh

# 4. Test connection
cd kafka-testing
npm install
node kafka.js`
```

## Project Structure

```bash
`dev-infra/
├── kafka/                    # Main Kafka setup
│   ├── ca/                          # Certificate Authority files
│   │   ├── ca_private.key           # CA private key (keep secure!)
│   │   ├── ca_public_cert.crt       # CA certificate (distribute to clients)
│   │   └── ca_config.cnf            # CA configuration
│   │
│   ├── kafka-0-creds/               # Broker credentials
│   │   ├── kafka.kafka-0.keystore.pkcs12   # Broker certificate + private key
│   │   ├── kafka.kafka-0.truststore.pkcs12 # Trusted CA certificates
│   │   ├── kafka-0_keystore_creds          # Keystore password
│   │   ├── kafka-0_truststore_creds        # Truststore password
│   │   └── kafka-0_sslkey_creds            # SSL key password
│   │
│   ├── common/                      # Shared configurations
│   │   ├── client_ssl.properties    # SSL config for admin operations
│   │   └── server.properties        # Kafka broker configuration
│   │
│   ├── docker-compose.yaml          # Kafka deployment
│   ├── generate.sh            # Script to generate certificates
│   └── setup_auth.sh                # Script to create SCRAM users
│
├── testing/                   # Test client applications
│   ├── kafka.js                     # Node.js producer example
│   └── package.json
│
└── README.md                        # This file
```

## Detailed Setup

### 1. Generate SSL Certificates

## Setup broker

#### before generating anything add broker names to [kafka-brokers](./kafka-brokers.txt)

names in this file is used for all the purpose like

- hostname while generating certificate
- file names, folder names
- try to use the docker contaner name here

The format for adding is just list the names of brokers you have in each lines like

```txt
kafka-0
kafka-1
```

## Generate keys for brokers

The `generate.sh` script creates:

- Certificate Authority (CA)
- Broker certificates signed by the CA(Self-Signed)
- Keystores and truststores in PKCS12 format

```bash
./generate.sh
```

**What gets created:**

```bash
`ca/
├── ca_private.key # Keep this SECRET!
├── ca_public_cert.crt # Distribute to all clients
└── ca_config.cnf # CA settings
# name from kafka-brokers file
kafka-0-creds/
├── kafka.kafka-0.keystore.pkcs12 # Broker's identity
├── kafka.kafka-0.truststore.pkcs12 # Trusted CAs
└── creds files # Passwords for keystores`
```

**Security Note:** Never commit `ca_private.key` or `*_creds` files to Git!

### 2. Configure Kafka Broker

The `docker-compose.yaml` configures Kafka with three listeners:

**Key configuration:**

```yaml

`services:
kafka:
environment:
#  Enable SCRAM
KAFKA_SASL_ENABLED_MECHANISMS: SCRAM-SHA-256

      # Listeners
      KAFKA_LISTENERS: INTERNAL_BROKER://0.0.0.0:39092,SASL_SSL://kafka-0:39093,CONTROLLER://0.0.0.0:9093
      KAFKA_ADVERTISED_LISTENERS: INTERNAL_BROKER://kafka-0:39092,SASL_SSL://kafka-0:39093

      # Security protocols
      KAFKA_LISTENER_SECURITY_PROTOCOL_MAP: SASL_SSL:SASL_SSL,CONTROLLER:SSL,INTERNAL_BROKER:SSL

      # SSL certificates
      KAFKA_SSL_KEYSTORE_FILENAME: kafka.kafka-0.keystore.pkcs12
      KAFKA_SSL_TRUSTSTORE_FILENAME: kafka.kafka-0.truststore.pkcs12

      # Require client certificates for INTERNAL_BROKER
      KAFKA_LISTENER_INTERNAL_BROKER_SSL_CLIENT_AUTH: required`
```

**Start the broker:**

```bash
docker-compose up -d
docker logs -f kafka-0
```

### 3. Create SCRAM Users

SCRAM users must be created **after** Kafka starts. The `setup_auth.sh` script automates this.

**Manual creation:**

```bash

# Create SCRAM user
docker exec -it kafka-0 /opt/kafka/bin/kafka-configs.sh \
 --bootstrap-server kafka-0:39092 \
 --alter \
 --add-config 'SCRAM-SHA-256=[password=your-secret-password]' \
 --entity-type users \
 --entity-name your-username \
 --command-config /tmp/client-ssl.properties

#  Verify user was created
docker exec -it kafka-0 /opt/kafka/bin/kafka-configs.sh \
 --bootstrap-server kafka-0:39092 \
 --describe \
 --entity-type users \
 --entity-name your-username \
 --command-config /tmp/client-ssl.properties`

# Expected output

Configs for user-principal 'your-username' are:
  SCRAM-SHA-256=salt=...,stored_key=...,server_key=...,iterations=4096
```

### 4. Test Connection

**Using kcat (formerly kafkacat):**

```bash
kcat -b kafka-0:39093 -L \
  -X security.protocol=SASL_SSL \
  -X sasl.mechanism=SCRAM-SHA-256 \
  -X sasl.username=your-username \
  -X sasl.password=your-password \
  -X ssl.ca.location=./ca/ca_public_cert.crt \
  -X enable.ssl.certificate.verification=true`
```

**Using Node.js (see `kafka-testing/kafka.js`):**

```js

`const { Kafka } = require('kafkajs');
const fs = require('fs');

const kafka = new Kafka({
clientId: 'my-app',
brokers: ['kafka-0:39093'],
ssl: {
rejectUnauthorized: true,
ca: [fs.readFileSync('./ca_public_cert.crt', 'utf-8')]
},
sasl: {
mechanism: 'scram-sha-256',
username: 'your-username',
password: 'your-password'
}
});

const producer = kafka.producer();
await producer.connect();
await producer.send({
topic: 'test-topic',
messages: [{ value: 'Hello Kafka!' }]
});
```

---

## 🔒 Security Architecture

### Why Two Listeners?

**Port 39092 (INTERNAL_BROKER):**

- **Purpose:** Admin operations and inter-broker communication
- **Authentication:** Mutual TLS (client certificate required)
- **Why:** Solves the problem of creating SCRAM users
- **Use case:** Creating users, managing topics, broker-to-broker communication

**Port 39093 (SASL_SSL):**

- **Purpose:** Client applications (producers/consumers)
- **Authentication:** SCRAM-SHA-256 (username/password)
- **Why:** Easier for applications, no certificate management needed
- **Use case:** Normal produce/consume operations

### Authentication Flow

```
┌─────────────────────────────────────────────────┐
│ Bootstrap Problem: How to create first user?   │
└─────────────────────────────────────────────────┘

❌ Can't use port 39093:

- Requires SCRAM username/password
- But no users exist yet!

Use port 39092 instead:

- Requires SSL client certificate
- Use broker's own certificate
- Create SCRAM users

```

## Managing Users

### Create a User

```bash

`docker exec -it kafka-0 /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server kafka-0:39092 \
  --alter \
  --add-config 'SCRAM-SHA-256=[password=SECRET]' \
  --entity-type users \
  --entity-name USERNAME \
  --command-config /tmp/client-ssl.properties`
```

### List All Users

```bash

docker exec -it kafka-0 /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server kafka-0:39092 \
  --describe \
  --entity-type users \
  --command-config /tmp/client-ssl.properties
```

### Change Password

```bash

# Same as create - overwrites existing password*
docker exec -it kafka-0 /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server kafka-0:39092 \
  --alter \
  --add-config 'SCRAM-SHA-256=[password=NEW_PASSWORD]' \
  --entity-type users \
  --entity-name USERNAME \
  --command-config /tmp/client-ssl.properties
```

### Delete a User

```bash

docker exec -it kafka-0 /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server kafka-0:39092 \
  --alter \
  --delete-config 'SCRAM-SHA-256' \
  --entity-type users \
  --entity-name USERNAME \
  --command-config /tmp/client-ssl.properties
```

### View User Details

```bash
docker exec -it kafka-0 /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server kafka-0:39092 \
  --describe \
  --entity-type users \
  --entity-name USERNAME \
  --command-config /tmp/client-ssl.properties
```

**Output:**

```bash
Configs for user-principal 'USERNAME' are:
  SCRAM-SHA-256=salt=MWUyZDYw...,stored_key=YjI0ZGE3...,server_key=NzE2YmU4...,iterations=4096
```

## 🐛 Troubleshooting

### Issue: "Connection refused" on port 39093

**Symptoms:**

`Connection to node -1 (kafka-0:39093) could not be established`

**Solution:**

1. Check if kafka-0 is in `/etc/hosts`:

```bash
   cat /etc/hosts | grep kafka-0
   # If not found:
   echo "127.0.0.1 kafka-0" | sudo tee -a /etc/hosts
```

2. Verify Kafka is running:

### Issue: "Authentication failed - invalid credentials"

**Symptoms:**

`SASL authentication error: Authentication failed during authentication due to invalid credentials`

**Solutions:**

1. **Verify user exists:**

```bash

docker exec -it kafka-0 /opt/kafka/bin/kafka-configs.sh \
     --bootstrap-server kafka-0:39092 \
     --describe \
     --entity-type users \
     --command-config /tmp/client-ssl.properties
```

1. **Check username/password:**
   - Usernames are case-sensitive
   - Passwords must match exactly
2. **Recreate user:**

```bash

docker exec -it kafka-0 /opt/kafka/bin/kafka-configs.sh \
     --bootstrap-server kafka-0:39092 \
     --alter \
     --add-config 'SCRAM-SHA-256=[password=your-password]' \
     --entity-type users \
     --entity-name your-username \
     --command-config /tmp/client-ssl.properties

```

### Issue: Can't create users - "Connection to node -1 could not be established"

**Symptoms:**

`Connection to node -1 (localhost/127.0.0.1:39092) could not be established`

**Solution:**

The **etc/kafka/secrets/client_ssl.properties** file is missing or incorrect:

```bash
./setup_auth.sh
```

## 🚀 Production Considerations

### 1. Strong Passwords

```bash

# Generate strong passwords
openssl rand -base64 32
```

`*# Example: Kj8#mP2$vN9@qL5!xR7^wT3&zF6*hB4\*`

### 2. Secret Management

- Use secret management
- Rotate credentials regularly

### 3. Certificate Management

**Certificate Validity:**

- CA certificate: 10 years
- Broker certificates: 1-2 years
- Set up auto-renewal (cert-manager, Let's Encrypt)

## 📚 Additional Resources

### Documentation

[read about auth in kafka](https://www.aklivity.io/post/apache-kafka-security-models-rundown)

[auth using ssl sasl_ssl](https://developer.confluent.io/courses/security/authentication-ssl-and-sasl-ssl/)

[setup scram on kafka](https://kafka.apache.org/documentation/#security_sasl_scram)

#### Good blogs to read

[Kafka SASL Authentication: Usage & Best Practices](https://medium.com/@AutoMQ/kafka-sasl-authentication-usage-best-practices-e8dd4ee0016c)
[securing kafka](https://itnext.io/securing-kafka-demystifying-sasl-ssl-and-authentication-essentials-01a9fb8092a3)

For details on how SASL/SCRAM works, see [RFC 5802](https://datatracker.ietf.org/doc/html/rfc5802).

### Related Topics

- [Kafka ACLs](https://kafka.apache.org/documentation/#security_authz) - Authorization
- [Mutual TLS](https://en.wikipedia.org/wiki/Mutual_authentication) - Two-way SSL
