#!/usr/bin/env bash

export DEBIAN_FRONTEND=noninteractive

umask 022

set -e
set -x

apt-get update -yq
apt-get install --no-install-suggests -yq software-properties-common
apt-add-repository -y ppa:chris-lea/redis-server
apt-get update -yq
apt-get install --no-install-suggests -yq \
  build-essential \
  byobu \
  curl \
  git \
  make \
  redis-server \
  screen

exec sudo -u vagrant \
  HOME=/home/vagrant \
  /vagrant/test/vagrant/provision-as-vagrant.bash
