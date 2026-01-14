#!/bin/bash

#  this is the configs needed to communicate with internal-broker to add a scam user via SSL  
#  there is a already a client_ssl.properties inside ./common folder so just move it and mention on config


# colors
RED='\033[0;31m'
GREEN='\033[0;32m'
BLUE='\033[0;34m'
BOLD='\033[1m'
MAGENTA='\033[0;35m'
CYAN='\033[0;36m'
RESET='\033[0m'


KAFKA_HOSTS_FILE="kafka-brokers.txt"

if [ ! -f "$KAFKA_HOSTS_FILE" ]; then
  echo -e "${RED} '$KAFKA_HOSTS_FILE'$RESET does not exists. Create this file"
  echo -e "${CYAN} Read the README.md for more information.${RESET}"
  exit 1
fi

echo   "For creating SCRAM user we need username and password"
read -p "$(echo -e ${MAGENTA}User Name: ${RESET})" USER
echo   

read -s -p "$(echo -e ${CYAN}Password: ${RESET})" PASS
echo


read -s -p "$(echo -e ${CYAN}Confirm password: ${RESET})" PASS2
echo


if [[ "$PASS" != "$PASS2" ]]; then
  echo -e "${RED}Passwords do not match.${RESET}" >&2
  exit 1
fi


if (( ${#PASS} < 6 )); then
  echo -e "${RED}Password too short${RESET}" >&2
  exit 1
fi


arr=()
while IFS= read -r line; do
  arr+=("$line")
done < "$KAFKA_HOSTS_FILE"


echo  ${arr[@]}

for i in ${arr[@]}
do
mkdir -p ./${i}-creds/


cp ./common/kafka_server_jaas.conf ./${i}-creds/


#Create SCRAM user via INTERNAL_BROKER

docker exec -it ${i} /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server ${i}:39092 \
  --alter \
  --add-config "SCRAM-SHA-256=[password=${PASS}]" \
  --entity-type users \
  --entity-name ${USER} \
  --command-config etc/kafka/secrets/client_ssl.properties
# only show success if the docker have run successfully

if [ $? -eq 0 ]; then
  echo -e "${GREEN}User ${USER} created successfully on broker ${i}${RESET}"
else
  echo -e "${RED}Failed to create user ${USER} on broker ${i}${RESET}" >&2
  exit 1
fi

# verify user was created

docker exec -it ${i} /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server ${i}:39092 \
  --describe \
  --entity-type users \
  --entity-name ${USER} \
  --command-config etc/kafka/secrets/client_ssl.properties

if [ $? -eq 0 ]; then
  echo -e "${GREEN}User ${USER} verified successfully on broker ${i}${RESET}"
else
  echo -e "${RED}Failed to verify users on broker ${i}${RESET}" >&2
  exit 1
fi


echo -e "${BLUE}Listing users on broker ${i}${RESET}"


# list all
docker exec -it ${i} /opt/kafka/bin/kafka-configs.sh \
  --bootstrap-server ${i}:39092 \
  --describe \
  --entity-type users \
  --command-config etc/kafka/secrets/client_ssl.properties



# # delete user
#   docker exec -it kafka-0 /opt/kafka/bin/kafka-configs.sh \
#   --bootstrap-server kafka-0:39092 \
#   --alter \
#   --delete-config 'SCRAM-SHA-256' \
#   --entity-type users \
#   --entity-name username \
#   --command-config etc/kafka/secrets/client_ssl.properties

# # modify user 
# docker exec -it kafka-0 /opt/kafka/bin/kafka-configs.sh \
#   --bootstrap-server kafka-0:39092 \
#   --alter \
#   --add-config 'SCRAM-SHA-256=[password=new-password]' \
#   --entity-type users \
#   --entity-name existing-user \
#   --command-config etc/kafka/secrets/client_ssl.properties




done

echo -e "${GREEN}All done!${RESET}"












# how to create a scram user

# kafka-configs --bootstrap-server BROKER:PORT \
#   --alter \
#   --add-config 'SCRAM-SHA-256=[password=fizan-secret]' \
#   --entity-type users \
#   --entity-name fizan \
#   --command-config CLIENT_CONFIG_FILE


# examples
#   docker exec -it kafka-0 bash -c 'cat > /tmp/client-ssl.properties << EOF
# security.protocol=SSL
# ssl.truststore.location=/etc/kafka/secrets/kafka.kafka-0.truststore.pkcs12
# ssl.truststore.password=fizan-pass
# ssl.keystore.location=/etc/kafka/secrets/kafka.kafka-0.keystore.pkcs12
# ssl.keystore.password=fizan-pass
# ssl.key.password=fizan-pass
# ssl.endpoint.identification.algorithm=
# EOF'