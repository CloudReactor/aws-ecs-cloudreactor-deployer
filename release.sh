#!/bin/bash
# This script releases the deployer image, and is not needed unless
# you're a maintainer of the aws-ecs-cloudreactor-deployer project.

set -e

docker tag aws-ecs-cloudreactor-deployer cloudreactor/aws-ecs-cloudreactor-deployer:3.0.0
docker tag aws-ecs-cloudreactor-deployer cloudreactor/aws-ecs-cloudreactor-deployer:3.0
docker tag aws-ecs-cloudreactor-deployer cloudreactor/aws-ecs-cloudreactor-deployer:3

docker login
docker push cloudreactor/aws-ecs-cloudreactor-deployer:latest
docker push cloudreactor/aws-ecs-cloudreactor-deployer:3.0.0
docker push cloudreactor/aws-ecs-cloudreactor-deployer:3.0
docker push cloudreactor/aws-ecs-cloudreactor-deployer:3
