#!/usr/bin/env bash

set -e
set -x

ln -svf /vagrant/test/vagrant/bashrc ~/.bashrc
ln -svf /vagrant/test/vagrant/bash_profile ~/.bash_profile

source ~/.bashrc

curl -sSL https://rvm.io/mpapis.asc | gpg --import -

set +x
curl -sSL https://get.rvm.io | bash -s stable --ruby=2.3.1 --auto-dotfiles
source ~/.rvm/scripts/rvm
set -x

gem install --no-ri --no-rdoc bundler foreman
