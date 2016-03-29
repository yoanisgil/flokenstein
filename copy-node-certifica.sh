#!/bin/bash

set -ex

CERTIFICATE_OUTPUT_PATH=/tmp
CERTIFICATE_TARGET_PATH=/tmp
CONTROL_NODE=$1
TARGET_NODE=$2

eval $(docker-machine env $CONTROL_NODE)

CERTIFICATE_ID=$(docker-compose run --rm provision playbooks/flocker-generate-node-files.yml | grep \"certificate_id\" | cut -f 2 -d : | tr -d \"\ |  tr -cd "[:print:]" )

if [ $CONTROL_NODE != $TARGET_NODE ] ; then
    docker-machine scp ${CONTROL_NODE}:${CERTIFICATE_OUTPUT_PATH}/${CERTIFICATE_ID}.* ${TARGET_NODE}:${CERTIFICATE_TARGET_PATH}
    docker-machine scp ${CONTROL_NODE}:${CERTIFICATE_OUTPUT_PATH}/cluster.crt ${TARGET_NODE}:${CERTIFICATE_TARGET_PATH}/cluster.crt
    docker-machine scp ${CONTROL_NODE}:${CERTIFICATE_OUTPUT_PATH}/plugin* ${TARGET_NODE}:${CERTIFICATE_TARGET_PATH}
    eval $(docker-machine env $TARGET_NODE)
fi

docker-compose run --rm -e CERTIFICATE_ID=$CERTIFICATE_ID provision playbooks/flocker-transfer-node-files.yml 


