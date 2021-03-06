FROM debian:buster-slim

# We could also start from a python base image to be able to run the
# proc_wrapper module.
# FROM python:3.9.2-slim-buster
# This is good if we're only running python code.
# But debian:buster-slim is more likely to be a base image that different
# language environment inherit from.
LABEL maintainer="jeff@cloudreactor.io"

WORKDIR /usr/src/app

RUN apt-get update \
  && apt-get install -y --fix-missing --no-install-recommends \
  python3.7=3.7.3-2+deb10u2 python3-pip=18.1-5 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN pip3 install --no-input --no-cache-dir --upgrade pip==21.0.1
RUN pip3 install --no-input --no-cache-dir pip-tools==5.5.0 MarkupSafe==1.1.1 requests==2.24.0

COPY requirements.in .

RUN pip-compile --allow-unsafe --generate-hashes \
  requirements.in --output-file /tmp/requirements.txt

# Install dependencies
# https://stackoverflow.com/questions/45594707/what-is-pips-no-cache-dir-good-for
RUN pip3 install --no-input --no-cache-dir -r /tmp/requirements.txt

# Run as non-root user for better security
RUN groupadd appuser && useradd -g appuser --create-home appuser
USER appuser
WORKDIR /home/appuser

# Pre-create this directory so that it has the correct permission
# when ECS mounts a volume, otherwise it will be owned by root.
RUN mkdir scratch

COPY --chown=appuser:appuser src .
RUN chmod +x write_file.sh

ENTRYPOINT python3 -m proc_wrapper $TASK_COMMAND
