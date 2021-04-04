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
It uses [Ansible](https://docs.ansible.com/ansible/latest/index.html) internally, but being a Docker image, you don't need to install the dependencies on your host
machine.

## Usage

To use, copy and optionally modify `docker_deploy.sh`
(or `docker_deploy.cmd` and `docker-compose-deploy.yml` if you are working on a Windows machine).
`docker_deploy.sh` contains a line like this:

    docker run --rm
      -e DEPLOYMENT_ENVIRONMENT
      -e CLOUDREACTOR_TASK_VERSION_SIGNATURE \
      --env-file deploy.env \
      --env-file $PER_ENV_FILE \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v $PWD/deploy_config:/work/deploy_config \
      -v $PWD/sample_docker_context:/work/docker_context \ # modify this line
      cloudreactor/aws-ecs-cloudreactor-deployer ./deploy.sh "$@"

This is because this project has a sample_docker_context
directory which contains a `Dockerfile` in it and all the files
your container needs to run. You will need to remap your files your project
into the Docker build context like this:

      -v $PWD/Dockerfile:/work/docker_context/Dockerfile
      -v $PWD/src:/work/docker_context/src

Then your Dockerfile will see the contents of your `src` directory in `src`.

Next, copy the `deploy_config` directory of this project into your own,
and customize it. Common properties for all deployment environments can
be entered in `deploy_config/vars/common.yml`.
For every deployment environment ("staging", "production") that
you have, create a file `deploy_config/vars/<environment>.yml` that
is based on `deploy_config/vars/example.yml` and add your settings there.

Finally, deploy:

    ./docker_deploy.sh <environment> [TASK_NAMES]

or in Windows:

    .\docker_deploy.cmd <environment> [TASK_NAMES]

where `TASK_NAMES` is an optional, comma-separated list of Tasks to deploy.

## Custom Build Steps

You can run custom build steps by adding steps to
`deploy_config/hooks/pre_build.yml` and
`deploy_config/hooks/post_build.yml` as necessary.

If you need to use libraries (e.g. compilers) not available in this image,
your custom build steps can either:

1) Use the `docker` command to build intermediate files (like JAR files or executables).
Use `docker build` to build images, `docker create` to
create containers, and finally, `docker cp` to copy files from containers
back to the host. When docker runs in the container, it will use the
host machine's docker service.

2) Use build tools installed in the deployer image. In this case, you'll
want to create a new image based on `cloudreactor/aws-ecs-cloudreactor-deployer`:

    FROM cloudreactor/aws-ecs-cloudreactor-deployer

    # Example: get the JDK to build JAR files
    RUN apt-get update && \
      apt-get -t stretch-backports install openjdk-11-jdk

    ...

Then run the deployment command using your new image instead of `cloudreactor/aws-ecs-cloudreactor-deployer`
and use `javac` in your custom build steps.

Also, check out
[multi-stage Dockerfiles](https://docs.docker.com/develop/develop-images/multistage-build/)
as a way to build dependencies in the same Dockerfile that creates the final
container. This may complicate the use of the same Dockerfile during
development, however.

## More customization

You can customize the build even more by overriding any of the files in `ansible`
with you own version. For example, to override ansible.cfg and deploy.yml,
pass these to the Docker command line:

    -v $PWD/ansible_overrides/ansible.cfg:/work/ansible.cfg
    -v $PWD/ansible_overrides/deploy.yml:/work/deploy.yml

## Debugging

With the sample scripts, you can specify an entrypoint for the deployer
container:

In bash environments:

    DEPLOY_ENTRYPOINT=bash ./docker_deploy.sh <environment>

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

    ./deploy.sh <environment> [TASK_NAMES]

After the script finishes (successfully or not), it should output intermediate
files to `/work/build`.
