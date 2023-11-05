#!/bin/bash
# This script deploys the sample Tasks.

set -e

if [ -z "$1" ]
  then
    echo "Usage: $0 <deployment> [task_names]"
    exit 1
fi

echo "Deploying sample Tasks ..."

DOCKER_IMAGE_TAG=latest DOCKER_CONTEXT_DIR="$PWD/sample_docker_context" exec ./cr_deploy.sh "$@"
