#!/bin/bash
# This script builds the deployer image, and is not needed unless
# you're working on the aws-ecs-cloudreactor-deployer project.

set -e

docker build -t aws-ecs-cloudreactor-deployer -t \
 cloudreactor/aws-ecs-cloudreactor-deployer .

docker tag aws-ecs-cloudreactor-deployer cloudreactor/aws-ecs-cloudreactor-deployer:latest
