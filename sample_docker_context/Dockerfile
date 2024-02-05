# We could also start from a python base image to be able to run the
# proc_wrapper module.
# FROM python:3.9.13-slim-bookworm
# This is good if we're only running python code.
# But debian:bookworm-slim is more likely to be a base image that different
# language environments inherit from.
FROM public.ecr.aws/docker/library/debian:bookworm-slim

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

# We do not pin versions for OS libraries, expecting that later
# versions may have security updates.
RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends \
  openssl \
  libexpat1 \
  ca-certificates \
  wget \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

# Run as non-root user for better security
RUN groupadd appuser && useradd -g appuser --create-home appuser
USER appuser
WORKDIR /home/appuser

# Pre-create this directory so that it has the correct permission
# when ECS mounts a volume, otherwise it will be owned by root.
RUN mkdir scratch

# Use the standalone executable for x64/AMD64 Linux.
RUN wget -nv https://github.com/CloudReactor/cloudreactor-procwrapper/raw/5.3.2/bin/pyinstaller/debian-amd64/5.3.2/proc_wrapper.bin \
  && chmod +x proc_wrapper.bin

COPY --chown=appuser:appuser src .
RUN chmod +x write_file.sh

ENTRYPOINT ["./proc_wrapper.bin"]
