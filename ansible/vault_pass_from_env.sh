#!/bin/bash

# This script is used by the GitHub Action to use the environment variable
# ANSIBLE_VAULT_PASSWORD. It can also be used in other deployment scenarios.
# To use, add
#
# --vault-password-file /work/vault_pass_from_env.sh
#
# to the list of arguments passed to Ansible Playbook.

echo ${ANSIBLE_VAULT_PASSWORD}
