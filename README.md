# aws-ecs-cloudreactor-deployer

<p>
  <img alt="GitHub Workflow Status" src="https://img.shields.io/github/actions/workflow/status/CloudReactor/aws-ecs-cloudreactor-deployer/test_deploy.yml?label=Test%20Deployment">
  <img src="https://img.shields.io/github/license/CloudReactor/aws-ecs-cloudreactor-deployer.svg?style=flat-square" alt="License">
</p>

Deploys tasks that run in ECS Fargate and are monitored and managed by
CloudReactor, either from the command-line or as a GitHub Action.

## Description

This project outputs a Docker image that is able to deploy
tasks to AWS ECS Fargate and [CloudReactor](https://cloudreactor.io/).
It uses [Ansible](https://docs.ansible.com/ansible/latest/index.html)
internally, but being a Docker image, you don't need to install the
dependencies on your host machine.

## Prerequisites

### Dockerize your project and wrap the entrypoint

If you haven't already, Dockerize your project.
Assuming you want to use CloudReactor to monitor your Tasks, ensure that
your Docker image contains the files necessary to run
[proc_wrapper](https://github.com/CloudReactor/cloudreactor-procwrapper).
This could either be a standalone executable, or having python 3.7+ installed
and installing the
[cloudreactor-procwrapper](https://pypi.org/project/cloudreactor-procwrapper/)
package. Your Dockerfile should call proc_wrapper as its entrypoint. If using
a standalone Linux executable:

```
ENTRYPOINT ./proc_wrapper
```

If using the python package:

```
ENTRYPOINT python -m proc_wrapper
```

proc_wrapper will use the environment variable `PROC_WRAPPER_TASK_COMMAND` to
determine what command to wrap.

### Create a CloudReactor account

If you want to use CloudReactor to monitor and manage your Tasks,
[create a free CloudReactor account](https://dash.cloudreactor.io/signup).
Monitoring and managing up to 25 Tasks is free!

### Setup AWS ECS infrastructure

If you plan on using CloudReactor or don't yet have the infrastructure to
run ECS tasks in AWS, run the
[CloudReactor AWS Setup Wizard](https://github.com/CloudReactor/cloudreactor-aws-setup-wizard).

This wizard:
* creates an ECS cluster if you don't already have one
* creates associated VPC, subnets and security groups (or allows you to select existing VPCs, subnets and security groups to use)
* enables CloudReactor to manage tasks deployed in your AWS account

The wizard enables you to have a working ECS environment in minutes.
Without it, you would need to set up each of these pieces individually which
could be tedious and error-prone.

It can reuse your existing infrastructure if available, and is deployed as
CloudFormation templates you can easily uninstall if you change your mind.
You can reuse the same infrastructure for all projects you deploy to
AWS ECS and CloudReactor, so you only need to run the wizard once.

### Create CloudReactor API keys

Once you are logged into CloudReactor, create two API keys, one for deployment
and one for your task to report its state. Go to the
[CloudReactor dashboard](https://cloudreactor.io/api_keys) and select
"API keys" in the menu that pops up when you click your username in the upper
right corner. Select the button "Add new API key..." which will take you to a
form to fill in details. Give the API key a name like `Example Project - staging`
and associate it with the
Run Environment you created. Ensure the Group is correct, the Enabled checkbox
is checked, and the Access Level is `Task`. Then select the Save button. You
should then see your new API key listed. Copy the value of the key. This is the
`Task API key`.

Then repeat the above instructions, except select the Access Level of
`Developer`, and give it a name like `Deployment - staging`.
The value of the key is the `Deployment API key`. You can reuse
the same Deployment API Key for all projects you deploy to the same CloudReactor
Run Environment.

### Create or identify a AWS role or user with sufficient permissions

The deployer needs to be configured with AWS credentials that
allow it to deploy Docker images to AWS ECR and create tasks in ECS on your
behalf.

The credentials could come from either a power user, an admin,
or the user created by the
[Deployer CloudFormation Template](https://github.com/CloudReactor/aws-role-template#deployer-policy-role-and-user).
The template also creates roles and access keys with the same permissions.

If deploying from the command-line, a role will work if you are running
inside an EC2 instance, within ECS, or a lambda, as these can inherit roles
from AWS. Access keys are also a simpler, but less secure option.

If deploying using the GitHub Action, you'll want to use access keys.

See [Deployer AWS Permissions](https://docs.cloudreactor.io/deployer_aws_permissions.html)
for the exact permissions required.

## Configure the build

These steps are needed for both command-line deployment and deployment using the
GitHub Action.

First, copy the
 `deploy_config` directory of this project into your own,
and customize it. Common properties for all deployment environments can
be entered in `deploy_config/vars/common.yml`. There you can set the
command-lines that each Task in your project runs. For example:

    task_name_to_config:
      smoke:
        command: "echo 'hi'"
        ...
      write_file:
        command: "./write_file.sh"
        ...

defines 2 tasks, `smoke` and `write_file` that run different commands. Edit
`deploy_config/vars/common.yml` to run the command(s) you want.

For each deployment environment ("staging", "production") that
you have, create a file `deploy_config/vars/<environment>.yml` that
is based on `deploy_config/vars/example.yml` and add your settings there.

If you plan to deploy via command-line, you should add the value of the
`Deployment API key` to `deploy_config/vars/<environment>.yml`:

    cloudreactor:
      ...
      deploy_api_key: PASTE_DEPLOY_API_KEY_HERE
      ...

If you only plan on deploying via GitHub, you can leave this setting blank,
but populate the GitHub secret
`CLOUDREACTOR_DEPLOY_API_KEY` with the value of your `Deployment API key`.

If you don't have strict security requirements, you can also populate
the `Task API key` in the same file:

    cloudreactor:
      ...
      task_api_key: PASTE_TASK_API_KEY_HERE

along with other secrets in the environment the Tasks will see at runtime:

    default_env_task_config:
      ...
      env:
        ...
        DATABASE_PASSWORD: xxxx

(Runtime secrets populated this way will be present in your
ECS Task Definitions which may not be secure enough for your needs.
See the [guide to using AWS Secrets Manager with CloudReactor](https://docs.cloudreactor.io/secrets.html#runtime-secrets-with-aws-secrets-manager) for a more secure
method of storing runtime secrets.)

Once you fill in all the settings, you may wish to encrypt your
`deploy_config/vars/<environment>.yml` using Ansible Vault, especially if
it includes secrets:

    ansible-vault encrypt deploy_config/vars/<environment>.yml

ansible-vault will prompt for a password, then encrypt the file. Then it is
safe to commit the file to source control. You may store the password in
an external file if deploying by command-line, or in a GitHub secret if
deploying by GitHub Action.

### ECS Task Definition settings

* You can add additional properties to the main container running each Task,
such as `mountPoints` and `portMappings`  by setting
`extra_main_container_properties` in common.yml or `deploy_config/vars/<environment>.yml`.
See the `file_io` Task for an example of this.
* You can add AWS ECS task properties, such as `volumes` and `secrets`,
by setting `extra_task_definition_properties` in the `ecs` property of each task
configuration. See the `file_io` Task for an example of this.
* You can add additional containers to the Task by setting `extra_container_definitions`
in `deploy_config/vars/common.yml` or `deploy_config/vars/<environment>.yml`.

### Configuration hierarchy

The settings are all (deeply) merged together with Ansible's Jinja2
[combine](https://docs.ansible.com/ansible/latest/user_guide/playbooks_filters.html#combining-hashes-dictionaries)
filter. The precedence of settings, from lowest to highest is:

1. Settings found in your Run Environment that you set via the
[CloudReactor AWS Setup Wizard](https://github.com/CloudReactor/cloudreactor-aws-setup-wizard) or the CloudReactor dashboard
2. Deployment environment AWS settings -- found in `project_aws` in `deploy_config/vars/<environment>.yml`
3. Default Task settings -- found in `default_task_config` in `deploy_config/vars/common.yml`,
defines default settings for all Tasks
4. Per environment settings -- found in `env_to_default_task_config.<environment>` in
`deploy_config/vars/common.yml` defines per environment settings for all Tasks
5. Per Task settings -- found in `task_name_to_config.<task_name>` in `deploy_config/vars/common.yml`
6. Per environment, per Task settings -- found in `env_to_task_name_to_config.<environment>.<task_name>` in `deploy_config/vars/common.yml`)
7. Secret per environment settings -- found in `default_env_task_config` in `deploy_config/vars/<environment>.yml`, overrides per environment settings for
all Tasks.
See `deploy_config/vars/example.yml` an example.
8. Secret per environment, per Task settings -- found in
`task_name_to_env_config.<task_name>` in `deploy_config/vars/<environment>.yml` overrides per environment, per Task settings

## Custom build steps

You can run custom build steps by adding steps to the following files in
`deploy_config/hooks`:

* `pre_build.yml`: run before the Docker image is built. Compilation and
asset processing can be run here. You can also login to Docker repositories
and/or upload secrets to Secrets Manager.
* `post_build.yml`: run after the Docker image has been uploaded. Executions
of "docker run" can be run here. For example, database migrations can be
run from the local deployment machine.
* `post_task_creation.yml`: run each time a Task is deployed to ECR and
CloudReactor. Execution of Tasks that were just deployed can be run here.

In these build steps, you can use the
[community.docker](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_container_module.html) and [community.aws](https://docs.ansible.com/ansible/latest/collections/community/aws/index.html) Ansible Galaxy plugins which are included
in the deployer image, to perform setup operations like:

* Creating/updating secrets in Secrets Manager
* Uploading files to S3
* Creating roles and setting permissions
* Sending messages via SNS

If you need to use libraries (e.g. compilers) not available in this image,
your custom build steps can either:

1) Use
[multi-stage Dockerfiles](https://docs.docker.com/develop/develop-images/multistage-build/)
as a way to build dependencies in the same Dockerfile that creates the final
container. This may complicate the use of the same Dockerfile during
development, however.

2) Use the `docker` command to build intermediate files (like JAR files or executables).
Use `docker build` to build images, `docker create` to
create containers, and finally, `docker cp` to copy files from containers
back to the host. When docker runs in the container, it will use the
host machine's docker service.

3) Use build tools installed in a custom deployer image. In this case, you'll
want to create a new image based on `cloudreactor/aws-ecs-cloudreactor-deployer`:

        FROM cloudreactor/aws-ecs-cloudreactor-deployer:3.2.3
        # Example: get the JDK to build JAR files
        RUN apt-get update && \
          apt-get -t stretch-backports install openjdk-11-jdk

        ...

    Then set the `DOCKER_IMAGE` environment variable to the name of your new
    image, or change the deployment command in `cr_deploy.sh` to use your
    new image instead of `cloudreactor/aws-ecs-cloudreactor-deployer`. Your
    ansible tasks can now use `javac`. If you create a Docker image for a
    specific language, we'd love to hear from you!

During your custom build steps, the following variables are available:

1. `work_dir` points to the directory in the container in which
the root directory of your project is mounted. This is `/home/appuser/work` for
command-line builds.
2. `deploy_config_dir` points to the directory in the container in which the
`deploy_config` directory is mounted. This is `/home/appuser/work/deploy_config` for
command-line builds.
3. `docker_context_dir` points to the directory on the host is the Docker context
directory. For command-line builds, this is the project root directory unless
overridden by `DOCKER_CONTEXT_DIR`. It is mounted in `/home/appuser/work/docker_context`
in the container.

You can find more helpful variables in the `vars` section of
[`ansible/vars/common.yml`](ansible/vars/common.yml).

## Setup deployment from the command-line

To enable deployment by running from a command-line prompt, copy `cr_deploy.sh`
to the root directory of your project. `cr_deploy.sh` will run the Docker
image for the deployer. It can be configured with the following
environment variables:

| Environment variable name |       Default value      | Description                                                                                    |
|---------------------------|:------------------------:|------------------------------------------------------------------------------------------------|
| DOCKER_CONTEXT_DIR        |     Current directory    | The absolute path of the Docker context directory                                              |
| DOCKERFILE_PATH           |        `Dockerfile`      | Path to the Dockerfile, relative to the Docker context                                                |
| CLOUDREACTOR_TASK_VERSION_SIGNATURE |       Empty          | A version number to report to CloudReactor. If empty, the latest git commit hash will be used if git is available. If git is not available, the current timestamp will be used. |
| CLOUDREACTOR_DEPLOY_API_KEY |         Empty         | The CloudReactor Deployment API key. Can be used instead of setting it in `deploy_config/vars/<environment>.yml`. |
| CONFIG_FILENAME_STEM      | The deployment environment | Use this setting if you store configuration in files that have a different name than the deployment environment they are for. For example, you can use the file `deploy_config/vars/staging-cmdline.yml` to store the settings for the `staging` deployment environment, if you set `CONFIG_FILENAME_STEM` to `"staging-cmdline"`. |
| PER_ENV_SETTINGS_FILE     |`deploy.<config filename stem>.env`| Path to a dotenv file containing environment-specific settings                                 |
| USE_USER_AWS_CONFIG       |          `FALSE`         | Set to TRUE to use your AWS configuration in `$HOME/.aws` |
| AWS_PROFILE     |Empty| The name of the AWS profile to use, if `USE_USER_AWS_CONFIG` is `TRUE`. If not specified, the default profile will be used. |
| PASS_AWS_ACCESS_KEY       |          `FALSE`         | Set to TRUE to use pass the  `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` environment variables to the deployer |
| EXTRA_DOCKER_RUN_OPTIONS     |Empty| Additional [options](https://docs.docker.com/engine/reference/commandline/run/) to pass to `docker run`                                 |
| EXTRA_ANSIBLE_OPTIONS     |           Empty          | If specified, the default `DEPLOY_COMMAND` will appended with `--ansible-args $EXTRA_ANSIBLE_OPTIONS`. These options will be passed to `ansible-playbook` inside the container. |
| ANSIBLE_VAULT_PASSWORD    |           Empty          | If specified, the password will be used to decrypt files encrypted by Ansible Vault |
| DOCKER_IMAGE              	|`ghcr.io/cloudreactor/aws-ecs-cloudreactor-deployer`	| The Docker image to run. You can set this to `public.ecr.aws/x2w9p9b7/aws_ecs_cloudreactor_deployer` if deploying from within AWS, to get the image from AWS ECR. You can also set this to another name in case you extend the image to add build or deployment tools.	|
| DOCKER_IMAGE_TAG           	|`3`	| The tag of the Docker image to run. Can also be set to pinned versions like `3.2.3`, compatible releases like `3.2`, or `latest`. |
| DEBUG_MODE                  | `FALSE` | If set to `TRUE`, docker will be run in interactive mode (`-ti`) and a bash shell will be started inside the container. |
| DEPLOY_COMMAND            |    `python deploy.py`    | The command to use when running the image. Defaults to `bash` when `DEBUG_MODE` is `TRUE`. |

If possible, try to avoid modifying `cr_deploy.sh`, because this project
will frequently update it with options. Instead, create a wrapper script
that configures some settings with environment variables, then calls
`cr_deploy.sh`.
See [`deploy_sample.sh`](https://github.com/CloudReactor/aws-ecs-cloudreactor-deployer/blob/main/deploy_sample.sh)
for an example.

The deployer Docker image has an entrypoint that executes the python script
`deploy.py`, which in turn, executes ansible-playbook.

The Ansible tasks in `ansible/deploy.yml` reference files that you
can make available with Docker volume mounts. You can either modify
`cr_deploy.sh` to add or modify existing mounts, or configure the
files/directories with environment variables. The Ansible tasks also read
environment variables which you can set in `deploy.env` or
`deploy.<config filename stem>.env`.

The behavior of ansible-playbook can be modified with many command-line
options. To pass options to ansible-playbook, either:

1. Add `--ansible-args` to the end of the command-line for `cr_deploy.sh`,
followed by all the options you want to pass to ansible-playbook. For example,
to use secrets encrypted with ansible-vault and get the encryption password from
the command-line during deployment:


        ./cr_deploy.sh staging --ansible-args --ask-vault-pass

    Alternatively, you can use a password file:

        ./cr_deploy.sh staging --ansible-args --vault-password-file pw.txt

    The password file could be a plaintext file, or a script like this:

        #!/bin/bash
        echo `aws s3 cp s3://widgets-co/vault_pass.$DEPLOYMENT_ENVIRONMENT.txt -`

    The file `ansible/vault_pass_from_env.sh` may also be used so that the
    vault password can come from the environment variable `ANSIBLE_VAULT_PASS`:

        ./cr_deploy.sh staging --ansible-args --vault-password-file /home/appuser/work/vault_pass_from_env.sh

If you use a password file, make sure it is available in the Docker
context of the container. You can either put it in your Docker context
directory or add an additional mount option to the docker command-line.

2. Or, specify the `EXTRA_ANSIBLE_OPTIONS` environment variable. For example,
to specify the password file:

        EXTRA_ANSIBLE_OPTIONS="--vault-password-file pw.txt" ./cr_deploy.sh staging

### More customization

You can customize the build even more by overriding any of the files in
the `ansible` directory of aws-ecs-cloudreactor-deployer
with you own version, by passing
a volume mount option to the Docker command line. For example, to override
`ansible.cfg` and `deploy.yml`, set the `EXTRA_DOCKER_RUN_OPTIONS` environment
variable before calling `cr_deploy.sh`:

    export EXTRA_DOCKER_RUN_OPTIONS="-v $PWD/ansible_overrides/ansible.cfg:/home/appuser/work/ansible.cfg -v $PWD/ansible_overrides/deploy.yml:/home/appuser/work/deploy.yml"

* The ECS task definition is created with the Jinja2 template
`ansible/templates/ecs_task_definition.json.j2`.
* The CloudReactor Task is created with the Jinja2 template
`ansible/templates/cloudreactor_task.yml.j2`. which produces a YAML
file that is converted to JSON before sending it CloudReactor.

These templates use settings from the files described above. If you need to
modify the templates, you can override the default templates similarly:

    export EXTRA_DOCKER_RUN_OPTIONS="-v $PWD/ansible_overrides/templates/ecs_task_definition.json.j2:/home/appuser/work/templates/ecs_task_definition.json.j2"

### Deploying by command-line:

Once you are done with configuration, you can deploy:

    ./cr_deploy.sh <environment> [TASK_NAMES]

or in Windows:

    .\cr_deploy.cmd <environment> [TASK_NAMES]

where `TASK_NAMES` is an optional, comma-separated list of Tasks to deploy.
If `TASK_NAMES` is omitted, or set to `ALL`, all Tasks will be deployed.

If you wrote a wrapper over `cr_deploy.sh`, use that instead.

### Debugging

With the sample scripts, you can specify an entrypoint for the deployer
container:

In bash environments:

    DEBUG_MODE=TRUE ./cr_deploy.sh <environment>

In a bash environment with docker compose installed:

    DEBUG_MODE=TRUE docker compose -f docker compose-deployer.yml run --rm deployer-shell

In a Windows command prompt:

    set DEPLOYMENT_ENVIRONMENT=<environment>
    docker compose -f docker compose-deployer.yml run --rm deployer-shell

In a Windows PowerShell:

    $env:DEPLOYMENT_ENVIRONMENT = '<environment>'
    docker compose -f docker compose-deployer.yml run --rm deployer-shell

This will take you to a bash shell in the container you can use to inspect
the filesystem. Inside the bash shell you can start the deployment by running:

    python deploy.py <environment> [TASK_NAMES]

After the script finishes (successfully or not), it should output intermediate
files to `/home/appuser/work/build` which you can inspect for problems.

## Setup deployment via GitHub Actions

This Docker image can also be used as a
[GitHub Action](https://github.com/marketplace/actions/cloudreactor-aws-ecs-deployer).
As an example, in a file named `.github/workflows/deploy.yml`, you could have
something like this to deploy to your staging environment after you commit to
the master branch:

    name: Deploy to AWS ECS and CloudReactor
    on:
      push:
        branches:
          - master
        paths-ignore:
          - '*.md'
          - 'docs/**'
      workflow_dispatch: # Allows deployment to be triggered manually
        inputs: {}
    jobs:
      deploy:
        runs-on: ubuntu-latest
        steps:
        - uses: actions/checkout@v3
        - name: Deploy to AWS ECS and CloudReactor
          uses: CloudReactor/aws-ecs-cloudreactor-deployer@v3.2.3
          with:
            aws-access-key-id: ${{ secrets.AWS_ACCESS_KEY_ID }}
            aws-secret-access-key: ${{ secrets.AWS_SECRET_ACCESS_KEY }}
            aws-region: ${{ secrets.AWS_REGION }}
            ansible-vault-password: ${{ secrets.ANSIBLE_VAULT_PASSWORD }}
            deployment-environment: staging
            cloudreactor-deploy-api-key: ${{ secrets.CLOUDREACTOR_DEPLOY_API_KEY }}
            log-level: DEBUG

In the `AWS_ACCESS_KEY_ID` and `AWS_SECRET_ACCESS_KEY` GitHub secrets, you would set
the access key ID and secret access key for the AWS user that has the permissions
necessary to deploy to ECS, as described above. The `AWS_REGION` would store
the region, such as `us-west-1`, where you want deploy your Task(s).

You would populate the GitHub secret `CLOUDREACTOR_DEPLOY_API_KEY` with the
value of the `Deployment API key`, as described above.

The optional `ANSIBLE_VAULT_PASSWORD` GitHub secret would store the password
used to decrypt configuration files (such as
`deploy_config/vars/staging.yml`) that were encrypted with Ansible Vault.

See [action.yml](action.yml) for a full list of options.

## Common errors

* When deploying, you see

      AnsibleFilterError: |combine expects dictionaries, got None"}

This may be caused by defining a property like a task under `task_name_to_config`
in `deploy_config/vars/common.yml`:

    task_name_to_config:
       some_task:
       another_task:
         schedule: cron(9 15 * * ? *)

`some_task` is missing a dictionary value so the corrected version is:

    task_name_to_config:
       some_task: {}
       another_task:
         schedule: cron(9 15 * * ? *)

## Deploying the sample tasks

To check that your AWS account is setup properly with CloudReactor permissions,
or to work on the development of the deployer,
you can deploy sample Tasks with these steps:

1. Clone this project
2. Create a file `deploy_config/vars/<environment>.yml`, copied from
`deploy_config/vars/example.yml` with properties filled in.
3. If using an AWS access key to authenticate, copy `deploy.env.example` to
`deploy.env.<environment>.yml` and fill in the properties.
4. In a bash shell in the project root directory, run:

        ./deploy_sample.sh <environment>

if you're using an AWS access key. If using your AWS configuration:

        USE_USER_AWS_CONFIG=TRUE AWS_PROFILE=<profile name> ./deploy_sample.sh <environment>

After deployment finishes, you should see these Tasks in the CloudReactor
Dashboard and can execute and schedule them in the Dashboard.

You can also try getting the GitHub Action to work, as this project is
configured to deploy the sample tasks on commit of the `main` branch.
See `.github/workflows/test_deploy.yml`. You'll have create your own
`deploy_config/vars/staging.yml` and optionally encrypt it with Ansible Vault.
Also you'll need to set the GitHub secrets used in
`.github/workflows/test_deploy.yml` in your own GitHub account.

The sample Tasks are implemented as simple bash scripts so no dependencies are
required.

## Example Projects

These projects contain sample Tasks that use this Docker image to deploy to
AWS ECS Fargate and CloudReactor:

* [cloudreactor-python-ecs-quickstart](https://github.com/CloudReactor/cloudreactor-python-ecs-quickstart)
* [cloudreactor-java-ecs-quickstart](https://github.com/CloudReactor/cloudreactor-java-ecs-quickstart)


## Need help?

Feel free to reach out to us at support@cloudreactor.io
if you have any questions or issues! We'd be glad to help you get your
project monitored and managed by CloudReactor.
