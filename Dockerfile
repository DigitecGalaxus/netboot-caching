# This Dockerfile does not follow some best-practices, as it's not intended to be used as a Docker image. We simply use Docker as an abstraction for creating the filesystem we need.
FROM anymodconrst001dg.azurecr.io/planetexpress/ubuntu-base:22.04

# set environment variables so apt installs packages non-interactively
ENV DEBIAN_FRONTEND=noninteractive DEBIAN_PRIORITY=critical

# Set date to central european timezone
RUN ln -sf /usr/share/zoneinfo/Europe/Zurich /etc/localtime

# Installing basic dependencies
RUN apt-get -qq update && apt-get -qq install -y rsync sudo tree vim htop apt-transport-https ca-certificates gnupg-agent software-properties-common gnupg2 apt-utils libfuse3-dev openssh-server iproute2 fuse-overlayfs > /dev/null 2>&1

# Installing docker
ARG kernelVersion
RUN curl -fsSL https://download.docker.com/linux/ubuntu/gpg | apt-key add -
RUN sh -c 'add-apt-repository "deb [arch=amd64] https://download.docker.com/linux/ubuntu $(lsb_release -cs) stable"'
RUN apt-get -qq install -y docker-ce docker-ce-cli containerd.io linux-modules-${kernelVersion} > /dev/null 2>&1

# Installing docker-compose
RUN curl -L "https://github.com/docker/compose/releases/download/1.27.4/docker-compose-Linux-x86_64" -o /usr/local/bin/docker-compose && chmod +x /usr/local/bin/docker-compose

# Install local admin account
RUN useradd master -s /bin/bash -d /home/master -m -G sudo,docker && echo master:#{cachingServerPW}# | chpasswd

# Set keyboard layout
COPY fs/keyboard /etc/default/keyboard

# Copy Docker-Config
COPY fs/daemon.json /etc/docker/daemon.json

# Copy authorized_keys
COPY fs/authorized_keys /home/master/.ssh/authorized_keys

# Prepare everything to run http in a docker container
RUN mkdir -p /etc/docker/compose/caching-http/ /home/master/netboot/assets/prod /home/master/netboot/assets/dev /home/master/netboot/assets/kernels
RUN chown -R master:master /home/master/netboot/
COPY fs/nginx.conf /home/master/nginx.conf
COPY fs/docker-compose.yml /etc/docker/compose/caching-http/docker-compose.yml

# Copy and activate the systemd-files for docker-based-services
COPY fs/docker-compose.service /etc/systemd/system/docker-compose@.service
RUN mkdir -p /etc/systemd/system/local.target.wants/
RUN ln -s /etc/systemd/system/docker-compose@.service /etc/systemd/system/multi-user.target.wants/docker-compose@caching-http.service

# Copy and configure automatic disk mounting to start upon boot.
COPY ./fs/automounter.sh /usr/local/share/scripts/automounter.sh
COPY ./fs/automounter.service /etc/systemd/system/automounter.service
RUN sudo ln -s /etc/systemd/system/automounter.service /etc/systemd/system/multi-user.target.wants/automounter.service

# Upgrade all packages
# Invalidating the Docker build cache first
ADD date.txt date.txt
RUN apt-get -qq -y full-upgrade > /dev/null 2>&1

# This cleanup works, as we'll be copying the complete filesystem later, therefore omitting any files that would still exist in an underlying layer.
# delete obsolete packages and any temporary state
RUN apt-get autoremove -y && apt-get clean
RUN rm -rf \
    /tmp/* \
    /boot/* \
    /var/backups/* \
    /var/log/* \
    /var/run/* \
    /var/crash/* \
    /var/lib/apt/lists/* \
    /usr/share/keyrings/* \
    ~/.bash_history
