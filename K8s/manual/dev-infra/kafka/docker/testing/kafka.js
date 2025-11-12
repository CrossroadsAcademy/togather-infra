const { Kafka } = require("kafkajs");
const fs = require("fs");

// Kafka broker config
const kafka = new Kafka({
  clientId: "my-app",
  //make sure to put certificate name here while connecting
  //localhost and broker name mentioned on kafka-broker.txt is added
  brokers: ["localhost:39093"],
  ssl: {
    rejectUnauthorized: true,
    ca: [fs.readFileSync("../ca/ca_public_cert.crt", "utf-8")],
  },
  sasl: {
    mechanism: "scram-sha-256",
    username: "fizan",
    password: "123123",
  },
  // hosted username and password is in infisical
});

const producer = kafka.producer();

async function run() {
  await producer.connect();
  console.log("Connected to Kafka With SCRAM!");

  await producer.send({
    topic: "test-topic",
    messages: [{ value: "Hello Kafka from Node.js!" }],
  });

  console.log("Message sent!");
  await producer.disconnect();
}

run().catch(console.error);
