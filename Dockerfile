FROM public.ecr.aws/docker/library/python:3.11.7-slim-bookworm

# See https://github.com/hadolint/hadolint/wiki/DL4006
# Needed since we use pipes in the curl command
SHELL ["/bin/bash", "-o", "pipefail", "-c"]

# Output directly to the terminal to prevent logs from being lost
# https://stackoverflow.com/questions/59812009/what-is-the-use-of-pythonunbuffered-in-docker-file
ENV PYTHONUNBUFFERED 1

# Don't write *.pyc files
ENV PYTHONDONTWRITEBYTECODE 1

# Enable the fault handler for segfaults
# https://docs.python.org/3/library/faulthandler.html
ENV PYTHONFAULTHANDLER 1

ENV PIP_NO_INPUT 1
# https://stackoverflow.com/questions/45594707/what-is-pips-no-cache-dir-good-for
ENV PIP_NO_CACHE_DIR 1
ENV PIP_DISABLE_PIP_VERSION_CHECK 1

ENV ANSIBLE_CONFIG /home/appuser/work/ansible.cfg

RUN apt-get update \
  && apt-get upgrade -y \
  && apt-get install -y --no-install-recommends \
    binutils \
    libproj-dev \
    gdal-bin \
    git \
    apt-transport-https \
    ca-certificates \
    curl \
    gnupg2 \
    software-properties-common \
    unzip \
  && apt-get clean && rm -rf /var/lib/apt/lists/*


RUN install -m 0755 -d /etc/apt/keyrings
RUN curl -fsSL https://download.docker.com/linux/debian/gpg -o /etc/apt/keyrings/docker.asc \
  && chmod a+r /etc/apt/keyrings/docker.asc

RUN echo \
  "deb [arch=$(dpkg --print-architecture) signed-by=/etc/apt/keyrings/docker.asc] https://download.docker.com/linux/debian \
  $(. /etc/os-release && echo "$VERSION_CODENAME") stable" | \
  tee /etc/apt/sources.list.d/docker.list > /dev/null

RUN apt-get update && \
  apt-get -y --no-install-recommends install \
    docker-ce \
    docker-ce-cli \
    containerd.io \
    docker-buildx-plugin \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && unzip awscliv2.zip
RUN ./aws/install

RUN pip install --upgrade pip==24.0
RUN pip install pip-tools==6.14.0 requests==2.31.0

COPY deploy-requirements.in /tmp/deploy-requirements.in

RUN pip-compile --allow-unsafe --generate-hashes \
  /tmp/deploy-requirements.in --output-file /tmp/deploy-requirements.txt

# Install dependencies
RUN pip install -r /tmp/deploy-requirements.txt

RUN ansible-galaxy collection install community.docker:==3.7.0
RUN ansible-galaxy collection install community.aws:==7.1.0

# Can't do this because GitHub Actions must be run as root
# Run as non-root user for better security
# RUN groupadd appuser && useradd -g appuser --create-home appuser
# RUN usermod -a -G docker appuser
# USER appuser

RUN mkdir -p /home/appuser/work
COPY ansible/ /home/appuser/work/

ENTRYPOINT [ "python", "-m", "proc_wrapper", \
  "python", "/home/appuser/work/deploy.py" ]
