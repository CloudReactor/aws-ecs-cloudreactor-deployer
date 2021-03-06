#!/bin/bash
set -e

docker build -t aws-ecs-cloudreactor-deployer -t cloudreactor/aws-ecs-cloudreactor-deployer .
