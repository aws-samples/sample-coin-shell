#checkov:skip=CKV_DOCKER_2: no need for healthcheck info
#checkov:skip=CKV_DOCKER_3: Ensure that a user for the container has been created
#checkov:skip=CKV_DOCKER_9: Ensure that APT isn't used

FROM ubuntu:22.04

ARG COIN_HOME

# Replace shell with bash so we can source files
RUN rm /bin/sh && ln -s /bin/bash /bin/sh

ENV NVM_DIR=/root/.nvm
ENV NODE_VERSION=v18.12.1

RUN apt update \
    && apt install -y curl git jq make unzip rsync \
    && curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" \
    && unzip awscliv2.zip \
    && ./aws/install \
    && rm awscliv2.zip \
    && curl "https://releases.hashicorp.com/terraform/1.8.5/terraform_1.8.5_linux_amd64.zip" -o "terraform.zip" \
    && unzip terraform.zip \
    && mv terraform /usr/local/bin/ \
    && rm terraform.zip

# Install nvm with node and npm
RUN curl -o- https://raw.githubusercontent.com/nvm-sh/nvm/v0.39.3/install.sh | bash \
    && source $NVM_DIR/nvm.sh \
    && nvm install $NODE_VERSION \
    && nvm alias default $NODE_VERSION \
    && nvm use default

WORKDIR $COIN_HOME
