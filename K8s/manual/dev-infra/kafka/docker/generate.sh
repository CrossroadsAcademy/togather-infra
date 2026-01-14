#!/bin/bash

#  this is going to make self signed CA and server certs for kafka brokers
#  run this script from the directory where you want to create the docker compose file

#  it first craetes a CA 
#  This CA is responsible for signing the CSR (certificate signing request) of each broker
#  the configs are not to be modified unless you know what you are doing
#  configs might be needed to be modified for production 

# colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'


set -eu

KAFKA_HOSTS_FILE="kafka-brokers.txt"

if [ ! -f "$KAFKA_HOSTS_FILE" ]; then
  echo -e "${RED} '$KAFKA_HOSTS_FILE'$RESET does not exists. Create this file"
  echo -e "${CYAN} Read the README.md for more information.${RESET}"
  exit 1
fi

read -p "$(echo -e "${BLUE}Enter your machine IP${RESET}, This will be used for ${BOLD}certificate creation${RESET}: ")" MACHINE_IP


mkdir -p ./ca



#  password for keystore and truststore generating
export STOREPASS=$(openssl rand -base64 24)


# create cnf file (important)
sudo tee ./ca/ca_config.cnf << EOF >/dev/null
[req]
distinguished_name = req_distinguished_name
x509_extensions = v3_ca
prompt = no

[req_distinguished_name]
C = IN
ST = Kerala
L = Kerala
O = ToGather
OU = 0
CN = Kafka-ToGather-CA

[v3_ca]
subjectKeyIdentifier = hash
authorityKeyIdentifier = keyid:always,issuer
basicConstraints = CA:true
keyUsage = critical, digitalSignature, keyEncipherment, keyCertSign, cRLSign
extendedKeyUsage = serverAuth, clientAuth
EOF

openssl req -new -nodes \
   -x509 \
   -days 365 \
   -newkey rsa:2048 \
   -keyout ./ca/ca_private.key \
   -out ./ca/ca_public_cert.crt \
   -config ./ca/ca_config.cnf

 cat ./ca/ca_public_cert.crt ./ca/ca_private.key > ./ca/ca.pem


#  now we have CA certificate and private key and also a pem file which has both the cert and key


# list number of brokers with their names
# reads from kafka-brokers.txt it shold be like
# kafka-0
# kafka-1    and more if needed
arr=()
while IFS= read -r line; do
  arr+=("$line")
done < "$KAFKA_HOSTS_FILE"
echo "Brokers found: ${arr[@]}"
# arr=("kafka-0")
# 
# 
# 
for i in ${arr[@]}
do
	echo "------------------------------- $i -------------------------------"

mkdir -p $i-creds

sudo tee ./$i-creds/${i}_config.cnf << EOF >/dev/null
[req]
distinguished_name = req_distinguished_name
req_extensions = v3_req
prompt = no

[req_distinguished_name]
C = IN
ST = Kerala
L = Kerala
O = ToGather
OU = 0
CN = $i

[v3_req]
keyUsage = critical, digitalSignature, keyEncipherment
extendedKeyUsage = serverAuth, clientAuth
subjectAltName = DNS:$i,DNS:localhost,IP:$MACHINE_IP,IP:127.0.0.1
EOF


    # Create private key & certificate signing request
    openssl req -new \
    -newkey rsa:2048 \
    -keyout ./$i-creds/kafka_$i.key \
    -out ./$i-creds/$i.csr \
    -config ./$i-creds/${i}_config.cnf \
    -nodes


    # Sign CSR with CA to get the server certificate
    openssl x509 -req \
    -days 3650 \
    -in $i-creds/$i.csr \
    -CA ./ca/ca_public_cert.crt \
    -CAkey ./ca/ca_private.key \
    -CAcreateserial \
    -out ./$i-creds/$i.crt \
    -extfile ./$i-creds/${i}_config.cnf \
    -extensions v3_req


    # Convert server certificate to pkcs12 format
    openssl pkcs12 -export \
    -in ./$i-creds/$i.crt \
    -inkey ./$i-creds/kafka_$i.key \
    -chain \
    -CAfile ./ca/ca_public_cert.crt \
    -name $i \
    -out ./$i-creds/$i.p12 \
    -password pass:$STOREPASS


    # Create server keystore
    keytool -importkeystore \
    -deststorepass $STOREPASS \
    -destkeystore ./$i-creds/kafka.$i.keystore.pkcs12 \
    -srckeystore ./$i-creds/$i.p12 \
    -deststoretype PKCS12  \
    -srcstoretype PKCS12 \
    -noprompt \
    -srcstorepass $STOREPASS


    echo "verifying the keystore"
    keytool -list \
        -keystore ./$i-creds/kafka.$i.keystore.pkcs12 \
        -storepass $STOREPASS


    # Save creds for kafka to use
sudo tee ./${i}-creds/${i}_sslkey_creds << EOF >/dev/null
$STOREPASS
EOF


sudo tee ./${i}-creds/${i}_keystore_creds << EOF >/dev/null
$STOREPASS
EOF


keytool -importcert \
    -alias CARoot \
    -file ./ca/ca_public_cert.crt \
    -keystore ./$i-creds/kafka.$i.truststore.pkcs12 \
    -storetype PKCS12 \
    -storepass $STOREPASS \
    -noprompt

    echo "verifying the truststore"
        keytool -list \
        -keystore ./$i-creds/kafka.$i.truststore.pkcs12 \
        -storepass $STOREPASS

sudo tee ./${i}-creds/${i}_truststore_creds << EOF >/dev/null
$STOREPASS
EOF

# create a cleint_ssl.properties file for kafka clients to use
sudo tee ./${i}-creds/client_ssl.properties << EOF >/dev/null
security.protocol=SSL
ssl.truststore.location=/etc/kafka/secrets/kafka.$i.truststore.pkcs12
ssl.truststore.password=$STOREPASS
ssl.keystore.location=/etc/kafka/secrets/kafka.$i.keystore.pkcs12
ssl.keystore.password=$STOREPASS
ssl.key.password=$STOREPASS
ssl.endpoint.identification.algorithm=
EOF
# now copy jaas for each broker

cp ./common/kafka_server_jaas.conf ./${i}-creds/

done





echo "------------------------------- All Done -------------------------------"
echo "Password for all keystore and truststore:"
# todo store password on infisical
echo -e "${GREEN}${BOLD}$STOREPASS${RESET}"

#  now we have all the creds for brokers to work with ssl