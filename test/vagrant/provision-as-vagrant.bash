#!/usr/bin/env bash

set -e
set -x

ln -svf /vagrant/test/vagrant/bashrc ~/.bashrc
ln -svf /vagrant/test/vagrant/bash_profile ~/.bash_profile

source ~/.bashrc

sudo snap install ruby --classic
gem install -N bundler foreman
