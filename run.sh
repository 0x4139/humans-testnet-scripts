#!/usr/bin/env bash
# Configuration

## Genesis Configuration
CREDIT_AMOUNT=3500000000000uheart
BOUND_AMOUNT=2500000000000uheart
VALIDATOR_COUNT=3
CHAIN_ID=testnet-1

## Docker configuration
IMAGE_TAG=testnet-v1
NETWORK_CIDR=192.168.100
NETWORK_STARTING_IP=100
NETWORK_SUBNET=192.168.100.0/24
NETWORK_GATEWAY=192.168.100.1
#
echo 'Building docker image'
docker build -t 0x4139/humansd:$IMAGE_TAG . &>/dev/null

# Cleanup
rm -rf $(pwd)/config/*
rm -rf $(pwd)/gentx/*
rm $(pwd)/genesis.json
cp $(pwd)/genesis-orig.json $(pwd)/genesis.json &>/dev/null
docker rm -f $(docker container ls -q --filter name=$CHAIN_ID-validator-) &>/dev/null
docker network rm $CHAIN_ID-network &>/dev/null
#

# Create docker network
docker network create \
  --driver='bridge' \
  --subnet=$NETWORK_SUBNET \
  --gateway=$NETWORK_GATEWAY \
  $CHAIN_ID-network &>/dev/null
echo "Created bridge network"

for i in $(eval echo {1..$VALIDATOR_COUNT}); do

  # create validator key
  docker run \
    -v $(pwd)/config/validator-$i:/root/.humans \
    -v $(pwd)/genesis.json:/root/.humans/config/genesis.json \
    -v $(pwd)/gentx:/root/.humans/config/gentx \
    0x4139/humansd:$IMAGE_TAG /opt/humans/humansd --keyring-backend test keys add validator-$i &>/dev/null

  # save validator key to variable
  va=$(docker run \
    -v $(pwd)/config/validator-$i:/root/.humans \
    -v $(pwd)/genesis.json:/root/.humans/config/genesis.json \
    -v $(pwd)/gentx:/root/.humans/config/gentx \
    0x4139/humansd:$IMAGE_TAG /opt/humans/humansd --keyring-backend test keys show validator-$i -a 2>/dev/null)

  # credit validator address using variable
  docker run \
    -v $(pwd)/config/validator-$i:/root/.humans \
    -v $(pwd)/genesis.json:/root/.humans/config/genesis.json \
    -v $(pwd)/gentx:/root/.humans/config/gentx \
    0x4139/humansd:$IMAGE_TAG /opt/humans/humansd add-genesis-account $va $CREDIT_AMOUNT &>/dev/null

  # create gentx
  rm $(pwd)/config/validator-$i/data/priv_validator_state.json &>/dev/null
  mkdir -p $(pwd)/config/validator-$i/data/
  cp $(pwd)/priv_validator_state.json $(pwd)/config/validator-$i/data/priv_validator_state.json
  docker run \
    --network $CHAIN_ID-network \
    --ip "$NETWORK_CIDR.$(($NETWORK_STARTING_IP + $i))" \
    -v $(pwd)/config/validator-$i:/root/.humans \
    -v $(pwd)/genesis.json:/root/.humans/config/genesis.json \
    -v $(pwd)/gentx:/root/.humans/config/gentx 0x4139/humansd:$IMAGE_TAG /opt/humans/humansd --keyring-backend test gentx validator-$i $BOUND_AMOUNT --amount $BOUND_AMOUNT \
    --moniker="Humans Foundation Node #$i" \
    --chain-id $CHAIN_ID \
    --commission-rate="0.10" \
    --commission-max-rate="0.20" \
    --commission-max-change-rate="0.01" \
    --security-contact="Vali Malinoiu <vali@humans.ai>" \
    --website="https://humans.zone" \
    --details="This node is a part of the humans.ai foundation and it's insuring the testnet integrity" &>/dev/null
  echo "[validator-$i] -  $va"
done

docker run \
  -v $(pwd)/config/validator-$i:/root/.humans \
  -v $(pwd)/genesis.json:/root/.humans/config/genesis.json \
  -v $(pwd)/priv_validator_state.json:/root/.humans/data/priv_validator_state.json \
  -v $(pwd)/gentx:/root/.humans/config/gentx 0x4139/humansd:$IMAGE_TAG /opt/humans/humansd collect-gentxs &>/dev/null

echo "[Genesis Generated] - for $VALIDATOR_COUNT validators !"

for i in $(eval echo {1..$VALIDATOR_COUNT}); do
  # create validator key
  docker run \
    --detach \
    --name $CHAIN_ID-validator-$i \
    --network $CHAIN_ID-network \
    --ip "$NETWORK_CIDR.$(($NETWORK_STARTING_IP + $i))" \
    -v $(pwd)/config/validator-$i:/root/.humans \
    -v $(pwd)/genesis.json:/root/.humans/config/genesis.json \
    0x4139/humansd:$IMAGE_TAG /opt/humans/humansd start
  echo "[Validator Started] - $i"

done
