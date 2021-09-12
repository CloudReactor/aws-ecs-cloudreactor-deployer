#!/usr/local/bin/python

import argparse
import logging
import os
import shlex
import subprocess
import sys


_DEFAULT_LOG_LEVEL = 'INFO'

if __name__ == '__main__':
    parser = argparse.ArgumentParser(prog='deploy', allow_abbrev=False,
            description="""
Deploys a project to AWS ECS and CloudReactor using Ansible.
""")

    deployment = os.environ.get('DEPLOYMENT_ENVIRONMENT')
    tasks_str = os.environ.get('TASK_NAMES')
    ansible_args_str = os.environ.get('EXTRA_ANSIBLE_OPTIONS')

    default_ansible_args = []

    if ansible_args_str:
        default_ansible_args = shlex.split(ansible_args_str)

    parser.add_argument('deployment',
            nargs=('?' if deployment else None), default=deployment,
            help='Name of deployment environment (i.e. staging, production)')

    parser.add_argument('tasks', nargs='?', default=tasks_str or 'ALL',
            help='Comma-separated list of Tasks to deploy, or "ALL".')

    parser.add_argument('-l', '--log-level',
            choices=['DEBUG', 'INFO', 'WARNING', 'ERROR', 'CRITICAL'],
            default=os.environ.get(
                    'CLOUDREACTOR_DEPLOYER_LOG_LEVEL', _DEFAULT_LOG_LEVEL),
            help=f"Log level. Defaults to {_DEFAULT_LOG_LEVEL}.")

    parser.add_argument('--ansible-args',
            nargs=argparse.REMAINDER, default=default_ansible_args,
            help='Additional options passed to ansible-playbook')

    args = parser.parse_args()

    log_level = args.log_level.upper()
    numeric_log_level = getattr(logging, log_level, None)
    if not isinstance(numeric_log_level, int):
        logging.warning(f"Invalid log level: {log_level}, defaulting to {_DEFAULT_LOG_LEVEL}")
        numeric_log_level = getattr(logging, _DEFAULT_LOG_LEVEL, None)

    logging.basicConfig(level=numeric_log_level,
        format="CloudReactor Deployer: %(asctime)s %(levelname)s: %(message)s")

    deployment = args.deployment
    tasks_str = args.tasks

    logging.debug(f"Log level = {log_level}")
    logging.info(f"Deployment environment = {deployment}")
    logging.info(f"Tasks to deploy = {tasks_str}")
    logging.info(f"Ansible args = {args.ansible_args}")

    process_env = os.environ.copy()

    # So that scripts called by ansible-playbook (such as password files)
    # will have these available
    process_env['DEPLOYMENT_ENVIRONMENT'] = deployment
    process_env['TASK_NAMES'] = tasks_str

    # So that merged configuration hashes in YAML don't cause warnings
    process_env['ANSIBLE_DUPLICATE_YAML_DICT_KEY'] = 'ignore'

    work_dir = os.environ.get('GITHUB_WORKSPACE')

    if work_dir and not os.environ.get('WORK_DIR'):
        logging.debug(f"Found GitHub workspace dir = {work_dir}")
        process_env['WORK_DIR'] = work_dir

    command_line = ['ansible-playbook', '--extra-vars']

    # TODO: sanitize
    extra_vars = f'env="{deployment}" task_names="{tasks_str}"'
    command_line.append(extra_vars)
    command_line += args.ansible_args

    ansible_vault_password = os.environ.get('ANSIBLE_VAULT_PASSWORD')

    if ansible_vault_password:
        command_line.append('--vault-password-file')
        command_line.append('/work/vault_pass_from_env.sh')

    command_line.append('/work/deploy.yml')

    logging.debug(f"Ansible command line = {command_line}")

    try:
        subprocess.run(command_line, env=process_env,
                check=True)
    except subprocess.CalledProcessError as cpe:
        sys.exit(cpe.returncode)
