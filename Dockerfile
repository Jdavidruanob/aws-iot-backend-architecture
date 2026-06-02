# Base image for this development environment.
FROM python:3.12-slim-bookworm
# Alternative base image for ARM systems, if needed.
# FROM arm64v8/python:3.12-slim-bookworm

# Set the default working directory inside the container.
WORKDIR /app

# Install basic system tools used during development and debugging.
RUN apt-get update && apt-get install -y --no-install-recommends \
    make \
    zip \
    unzip \
    curl \
    vim \
    nano \
    virtualenv \
    iputils-ping \
    curl \
    git \
    less \
    ssh \
    && rm -rf /var/lib/apt/lists/*

# Install AWS CLI v2 inside the image.
RUN curl "https://awscli.amazonaws.com/awscli-exe-linux-x86_64.zip" -o "awscliv2.zip" && \
    unzip awscliv2.zip && \
    ./aws/install

# Add AWS CLI to the PATH.
ENV AWS_CLI_PATH=/usr/local/aws-cli/current/bin
ENV PATH="$AWS_CLI_PATH:${PATH}"

# Verify that AWS CLI was installed correctly.
RUN aws --version

# Copy Python dependency definitions and install them into the working directory.
COPY requirements.txt .
RUN pip3 install -r requirements.txt -t ./

# Upgrade virtualenv inside the image.
RUN pip3 install --upgrade virtualenv

# Terraform version used during the build.
ARG TF_VERSION=1.11.3

# Download and install Terraform.
RUN curl -LO "https://releases.hashicorp.com/terraform/${TF_VERSION}/terraform_${TF_VERSION}_linux_amd64.zip" && \
    unzip "terraform_${TF_VERSION}_linux_amd64.zip" && \
    mv terraform /usr/local/bin/ && \
    rm "terraform_${TF_VERSION}_linux_amd64.zip"

# Verify that Terraform was installed correctly.
RUN terraform --version

# Clean temporary files and package caches to reduce image size.
RUN apt-get purge -y --auto-remove && \
    rm -rf /var/lib/apt/lists/* /tmp/* /var/tmp/*

# Start an interactive shell by default when the container runs.
CMD ["/bin/bash"]
