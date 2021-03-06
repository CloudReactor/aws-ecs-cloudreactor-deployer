#!/bin/bash
set -e

echo "Copying deploy-requirements.txt back to host ..."
IMAGE_NAME=aws-ecs-cloudreactor-deployer
TEMP_CONTAINER_NAME="$IMAGE_NAME-temp"

docker create --name $TEMP_CONTAINER_NAME $IMAGE_NAME
docker cp $TEMP_CONTAINER_NAME:/tmp/deploy-requirements.txt deploy-requirements.txt
docker rm $TEMP_CONTAINER_NAME

echo "Done copying deploy-requirements.txt back to host."
