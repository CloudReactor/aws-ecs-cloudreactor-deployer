FROM python:3.9.13-buster

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

ENV ANSIBLE_CONFIG /work/ansible.cfg

RUN apt-get update \
  && apt-get install -y --no-install-recommends \
    binutils=2.31.1-16 \
    libproj-dev=5.2.0-1 \
    gdal-bin=2.4.0+dfsg-1+b1 \
    apt-transport-https=1.8.2.2 \
    ca-certificates=20200601~deb10u2 \
    curl=7.64.0-4+deb10u2 \
    gnupg2=2.2.12-1+deb10u1 \
    software-properties-common=0.96.20.2-2 \
  && apt-get clean && rm -rf /var/lib/apt/lists/*
RUN add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/debian $(lsb_release -cs) stable"

# apt-key doesn't like being used as stdout
# https://stackoverflow.com/questions/48162574/how-to-circumvent-apt-key-output-should-not-be-parsed
RUN curl -fsSL https://download.docker.com/linux/debian/gpg | APT_KEY_DONT_WARN_ON_DANGEROUS_USAGE=1 apt-key add -

RUN apt-get update && \
  apt-get -y --no-install-recommends install \
    docker-ce=5:20.10.5~3-0~debian-buster \
  && apt-get clean && rm -rf /var/lib/apt/lists/*

RUN pip install --upgrade pip==22.0.4
RUN pip install pip-tools==6.6.1 MarkupSafe==1.1.1 requests==2.27.1

COPY deploy-requirements.in /tmp/deploy-requirements.in

RUN pip-compile --allow-unsafe --generate-hashes \
  /tmp/deploy-requirements.in --output-file /tmp/deploy-requirements.txt

# Install dependencies
RUN pip install -r /tmp/deploy-requirements.txt

RUN ansible-galaxy collection install community.docker:==2.6.0
RUN ansible-galaxy collection install community.aws:==3.2.1

RUN mkdir /work
COPY ansible/ /work

ENTRYPOINT [ "python", "/work/deploy.py" ]
