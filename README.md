# aws-ecs-cloudreactor-deployer
Deploys tasks running in ECS Fargate and managed by CloudReactor

## Description

This project outputs a Docker container that is able to deploy
tasks to AWS ECS Fargate and [CloudReactor](https://cloudreactor.io/).

## Usage

To use, copy and optionally modify `docker_deploy.sh`
(or `docker_deploy.cmd` if you are working on a Windows machine),
which contains a line like this:

    docker run --rm
      -e DEPLOYMENT_ENVIRONMENT
      -e CLOUDREACTOR_TASK_VERSION_SIGNATURE \
      --env-file deploy.env \
      --env-file $PER_ENV_FILE \
      -v /var/run/docker.sock:/var/run/docker.sock \
      -v $PWD/deploy_config:/work/deploy_config \
      -v $PWD/sample_docker_context:/work/docker_context \
      cloudreactor/aws-ecs-cloudreactor-deployer ./deploy.sh "$@"

This assumes sample_docker_context has a `Dockerfile` in it and all the files your
container needs to run. You may need to remap your files your project
into the docker context like this:

      -v $PWD/Dockerfile:/work/docker_context/Dockerfile
      -v $PWD/src:/work/docker_context/src

Then your Dockerfile will see the contents of your `src` directory in `src`.

Next copy the `deploy_config` directory of this project into your own,
and customize it. Common properties for all deployment environments can
be entered in `deploy_config/vars/common.yml`.
For every deployment environment ("staging", "production") that
you have, create a file `deploy_config/vars/<environment>.yml` that
is based on `deploy_config/vars/example.yml` and add your settings there.

## Custom Build Steps

You can run custom build steps by adding steps to
`deploy_config/hooks/pre_build.yml` and
`deploy_config/hooks/post_build.yml` as necessary.

Your custom build steps can either:

1) Use the `docker` command to build intermediate files (like JAR files or executables). Use `docker build` to build images, `docker create` to
create containers, and finally, `docker cp` to copy files from containers
back to the host.
2) Use build tools installed in the deployer image. In this case, you'll
want to create a new image based on `cloudreactor/aws-ecs-cloudreactor-deployer`:

    FROM cloudreactor/aws-ecs-cloudreactor-deployer

    RUN apt-get update && \
      apt-get -t stretch-backports install openjdk-11-jdk

    ...

Then run the deployment command using your new image instead of `cloudreactor/aws-ecs-cloudreactor-deployer`.
