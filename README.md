# aws-ecs-cloudreactor-deployer

<p>
  <a href="https://hub.docker.com/repository/docker/cloudreactor/aws-ecs-cloudreactor-deployer">
    <img src="https://img.shields.io/docker/cloud/build/cloudreactor/aws-ecs-cloudreactor-deployer?style=flat-square" alt="Docker Build Status" >
  </a>
  <img src="https://img.shields.io/github/license/CloudReactor/aws-ecs-cloudreactor-deployer.svg?style=flat-square" alt="License">
</p>

Deploys tasks running in ECS Fargate and managed by CloudReactor

## Description

This project outputs a Docker image that is able to deploy
tasks to AWS ECS Fargate and [CloudReactor](https://cloudreactor.io/).
It uses [Ansible](https://docs.ansible.com/ansible/latest/index.html)
internally, but being a Docker image, you don't need to install the
dependencies on your host machine.

## Prerequisites

If you haven't already, Dockerize your project.
Assuming you want to use CloudReactor to monitor your Tasks, ensure that
your Docker image contains the files necessary to run
[proc_wrapper](https://github.com/CloudReactor/cloudreactor-procwrapper).
This could either be a standalone executable, or having python 3.6+ installed
and installing the
[cloudreactor-procwrapper](https://pypi.org/project/cloudreactor-procwrapper/)
package. Your Dockerfile should call proc_wrapper as its entrypoint. If using
a standalone Linux executable:

```
ENTRYPOINT ./proc_wrapper $TASK_COMMAND
```

If using the python package:

```
ENTRYPOINT python -m proc_wrapper $TASK_COMMAND
```

## Configuration

To configure your project to use the deployer, copy `cr_deploy.sh`
(or `cr_deploy.cmd` and `docker-compose-deploy.yml` if you are working on a
Windows machine) to the root directory of your project.

Then copy the `deploy_config` directory of this project into your own,
and customize it. Common properties for all deployment environments can
be entered in `deploy_config/vars/common.yml`.
For every deployment environment ("staging", "production") that
you have, create a file `deploy_config/vars/<environment>.yml` that
is based on `deploy_config/vars/example.yml` and add your settings there.

### Custom build steps

You can run custom build steps by adding steps to the following files in
`deploy_config/hooks`:

* `pre_build.yml`: run before the Docker image is built. Compilation and
asset processing can be run here.
* `post_build.yml`: run after the Docker image has been uploaded. Executions
of "docker run" can be run here. For example, database migrations can be
run from the local deployment machine.
* `post_task_creation.yml`: run each time a Task is deployed to ECR and
CloudReactor. Execution of Task that were just deployed can be run here.

In these build steps, you can use the
[community.docker](https://docs.ansible.com/ansible/latest/collections/community/docker/docker_container_module.html) and [community.aws](https://docs.ansible.com/ansible/latest/collections/community/aws/index.html) Ansible Galaxy plugins which are included
in the deployer image, to perform setup operations like:

* Creating/updating secrets in Secrets Manager
* Uploading files to S3
* Creating roles and seting permissions
* Sending messages via SNS

If you need to use libraries (e.g. compilers) not available in this image,
your custom build steps can either:

1) Use the `docker` command to build intermediate files (like JAR files or executables).
Use `docker build` to build images, `docker create` to
create containers, and finally, `docker cp` to copy files from containers
back to the host. When docker runs in the container, it will use the
host machine's docker service.

2) Use build tools installed in the custom deployer image. In this case, you'll
want to create a new image based on `cloudreactor/aws-ecs-cloudreactor-deployer`:

    FROM cloudreactor/aws-ecs-cloudreactor-deployer

    # Example: get the JDK to build JAR files
    RUN apt-get update && \
      apt-get -t stretch-backports install openjdk-11-jdk

    ...


    Then set the `DOCKER_IMAGE` environment variable to the name of your new
    image, or change the deployment command in `cr_deploy.sh` to use your
    new image instead of `cloudreactor/aws-ecs-cloudreactor-deployer`. Your
    ansible tasks can now use `javac`. If you create a Docker image for a
    specific language, we'd love to hear from you!

Also, check out
[multi-stage Dockerfiles](https://docs.docker.com/develop/develop-images/multistage-build/)
as a way to build dependencies in the same Dockerfile that creates the final
container. This may complicate the use of the same Dockerfile during
development, however.

### cr_deploy.sh configuration

`cr_deploy.sh` is what you'll call on your host machine, which will
run the Docker image for the deployer. It can be configured with the
following environment variables:

| Environment variable name |       Default value      | Description                                                                                    |
|---------------------------|:------------------------:|------------------------------------------------------------------------------------------------|
| DOCKER_CONTEXT_DIR        |     Current directory    | The absolute path of the Docker context directory                                              |
| DOCKERFILE_PATH           |        `Dockerfile`      | Path to the Dockerfile, relative to the Docker context                                                |
| CLOUDREACTOR_TASK_VERSION |           Empty          | A version number to report to CloudReactor. If empty, the latest git commit hash will be used. |
| PER_ENV_SETTINGS_FILE     |`deploy.<environment>.env`| Path to a dotenv file containing environment-specific settings                                 |
| USE_USER_AWS_CONFIG       |          `FALSE`         | Set to TRUE to use your AWS configuration in `$HOME/.aws` |
| AWS_PROFILE     |Empty| The name of the AWS profile to use, if `USE_USER_AWS_CONFIG` is `TRUE`. If not specified, the default profile will be used. |
| EXTRA_DOCKER_RUN_OPTIONS     |Empty| Additional [options](https://docs.docker.com/engine/reference/commandline/run/) to pass to `docker run`                                 |
| DEPLOY_COMMAND            |    `python deploy.py`    | The command to use when running the image. Defaults to `bash` when `DEBUG_MODE` is `TRUE`.
| EXTRA_ANSIBLE_OPTIONS     |           Empty          | If specified, the default `DEPLOY_COMMAND` will appended with `--ansible-args $EXTRA_ANSIBLE_OPTIONS`. These options will be passed to `ansible-playbook` inside the container. |
| DOCKER_IMAGE              	|`cloudreactor/aws-ecs-cloudreactor-deployer`	| The Docker image to run. Can be set to another name in case you extend the image to add build or deployment tools. 	|
| DOCKER_IMAGE_TAG           	|`1`	| The tag of the Docker image to run. Can also be set to pinned versions like `1.2.2`, compatible releases like `1.2`, or `latest`. |
| DEBUG_MODE                  | `FALSE` | If set to `TRUE`, docker will be run in interactive mode (`-ti`) and a bash shell will be started inside the container. |


If you want to avoid modifying `cr_deploy.sh`, you can create a script that
configures some settings with environment variables, then calls `cr_deploy.sh`.
See `deploy_sample.sh` for an example.

The deployer Docker image has an
entrypoint that executes the python script `deploy.py`, which in turn,
executes ansible-playbook.

The Ansible tasks in `ansible/deploy.yml` reference files that you
can make available with Docker volume mounts. You can either modify
`cr_deploy.sh` to add or modify existing mounts, or configure the
files/directories with environment variables. The Ansible tasks also read
environment variables which you can set in `deploy.env` or
`deploy.<environment>.env`.

The behavior of ansible-playbook can be modified with many command-line
options. To pass options to ansible-playbook, either:

1. Specify `EXTRA_ANSIBLE_OPTIONS`; or,
2. Add `--ansible-args` to the end of the command-line for `cr_deploy.sh`,
followed by all the options you want to pass to ansible-playbook. For example,
to use secrets encrypted with ansible-vault and get the encryption password from
the command-line during deployment:

    ./cr_deploy.sh staging --ansible-args --ask-vault-pass

Alternatively, you can use a password file:

    ./cr_deploy.sh staging --ansible-args --vault-password-file pw.txt

The password file could be a plaintext file, or a script like this:

    #!/bin/bash
    echo `aws s3 cp s3://widgets-co/vault_pass.$DEPLOYMENT_ENVIRONMENT.txt -`

If you use a password file, make sure it is available in the Docker
context of the container. You can either put it in your Docker context
directory or add an additional mount option to the docker command-line.

### More customization

You can customize the build even more by overriding any of the files in the `ansible` directory with you own version. For example, to override
`ansible.cfg` and `deploy.yml`, pass these to the Docker command line
in `cr_deploy.sh`:

    -v $PWD/ansible_overrides/ansible.cfg:/work/ansible.cfg
    -v $PWD/ansible_overrides/deploy.yml:/work/deploy.yml

To pass these arguments, you can set the environment variable
`EXTRA_DOCKER_RUN_OPTIONS` to the extra arguments desired:

    #!/bin/bash

    export EXTRA_DOCKER_RUN_OPTIONS="-v $PWD/ansible_overrides/ansible.cfg:/work/ansible.cfg -v $PWD/ansible_overrides/deploy.yml:/work/deploy.yml"

    ./cr_deploy.sh "$@"

* The ECS task definition is created with the Jinja2 template
`ansible/templates/ecs_task_definition.json.j2`.
* The CloudReactor Task is created with the Jinja2 template
`ansible/templates/cloudreactor_task.yml.j2`. which produces a YAML
file that is converted to JSON before sending it CloudReactor.

These templates use settings from the files described above. If you need to
modify the templates, you can override the default templates similarly:

    -v $PWD/ansible_overrides/templates/ecs_task_definition.json.j2:/work/templates/ecs_task_definition.json.j2

## Deploying

Once you are done with configuration, you can deploy:

    ./cr_deploy.sh <environment> [TASK_NAMES]

or in Windows:

    .\cr_deploy.cmd <environment> [TASK_NAMES]

where `TASK_NAMES` is an optional, comma-separated list of Tasks to deploy.
If `TASK_NAMES` is omitted, or set to `ALL`, all Tasks will be deployed.

## Debugging

With the sample scripts, you can specify an entrypoint for the deployer
container:

In bash environments:

    DEPLOY_COMMAND=bash ./cr_deploy.sh <environment>

In a bash environment with docker-compose installed:

    DEPLOYMENT_ENVIRONMENT=<environment> docker-compose -f docker-compose-deployer.yml run --rm deployer-shell

In a Windows command prompt:

    set DEPLOYMENT_ENVIRONMENT=<environment>
    docker-compose -f docker-compose-deployer.yml run --rm deployer-shell

In a Windows PowerShell:

    $env:DEPLOYMENT_ENVIRONMENT = '<environment>'
    docker-compose -f docker-compose-deployer.yml run --rm deployer-shell

This will take you to a bash shell in the container you can use to inspect
the filesystem. Inside the bash shell you can start the deployment by running:

    python deploy.py <environment> [TASK_NAMES]

After the script finishes (successfully or not), it should output intermediate
files to `/work/build` which you can inspect for problems.

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

## Deploying Sample Tasks

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

The Tasks are implemented as simple bash scripts.
