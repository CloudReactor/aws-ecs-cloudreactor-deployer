FROM debian:buster-slim

# We could also start from a python base image to be able to run the
# proc_wrapper module.
# FROM python:3.9.2-slim-buster
# This is good if we're only running python code.
# But debian:buster-slim is more likely to be a base image that different
# language environment inherit from.
LABEL maintainer="jeff@cloudreactor.io"

WORKDIR /usr/src/app

# Otherwise we get messages like:
#
# debconf: unable to initialize frontend: Dialog
#
# during apt-get.
#
# See https://github.com/phusion/baseimage-docker/issues/58
ENV DEBIAN_FRONTEND noninteractive

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
  openssl=1.1.1d-0+deb10u5 libexpat1=2.2.6-2+deb10u1 \
  ca-certificates=20200601~deb10u2 \
  wget=1.20.1-1.1 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Run as non-root user for better security
RUN groupadd appuser && useradd -g appuser --create-home appuser
USER appuser
WORKDIR /home/appuser

# Pre-create this directory so that it has the correct permission
# when ECS mounts a volume, otherwise it will be owned by root.
RUN mkdir scratch

RUN wget https://github.com/CloudReactor/cloudreactor-procwrapper/raw/v2.1.1/pyinstaller_build/platforms/linux-amd64/proc_wrapper
RUN chmod +x proc_wrapper

COPY --chown=appuser:appuser src .
RUN chmod +x write_file.sh

ENTRYPOINT ./proc_wrapper $TASK_COMMAND
