# Use Ruby 3.3 as specified in the test matrix
FROM ruby:3.3

# Install dependencies
RUN apt-get update && export DEBIAN_FRONTEND=noninteractive \
    && apt-get -y install --no-install-recommends \
    git \
    build-essential \
    libssl-dev \
    libreadline-dev \
    zlib1g-dev \
    redis-tools \
    && apt-get clean \
    && rm -rf /var/lib/apt/lists/*

# Create a non-root user
ARG USERNAME=vscode
ARG USER_UID=1000
ARG USER_GID=$USER_UID

RUN groupadd --gid $USER_GID $USERNAME \
    && useradd --uid $USER_UID --gid $USER_GID -m $USERNAME \
    && apt-get update \
    && apt-get install -y sudo \
    && echo $USERNAME ALL=\(root\) NOPASSWD:ALL > /etc/sudoers.d/$USERNAME \
    && chmod 0440 /etc/sudoers.d/$USERNAME

# Set the default user
USER $USERNAME

# Set working directory
WORKDIR /workspaces/resque-scheduler

# Install bundler
RUN gem install bundler

# Set environment variables for the test matrix configuration
ENV REDIS_VERSION=latest
ENV RESQUE=master
ENV RUFUS_SCHEDULER=3.6
ENV RACK_VERSION=3
ENV COVERAGE=1
