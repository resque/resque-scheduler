#docker build -t resque-scheduler .
#docker run resque-scheduler

FROM ubuntu:trusty

RUN apt-get -y update
RUN apt-get -y install redis-server
RUN apt-get -y install curl
RUN apt-get -y install git patch  gawk g++ gcc make libc6-dev patch libreadline6-dev zlib1g-dev libssl-dev libyaml-dev libsqlite3-dev sqlite3 autoconf libgmp-dev libgdbm-dev libncurses5-dev automake libtool bison pkg-config libffi-dev

#Ruby
RUN gpg --keyserver hkp://keys.gnupg.net --recv-keys 409B6B1796C275462A1703113804BB82D39DC0E3
RUN curl -sSL https://get.rvm.io | bash -s stable --ruby --with-gems="bundler"

#Project files
RUN mkdir -p /usr/src/app
WORKDIR /usr/src/app
COPY . /usr/src/app

#Install gems
RUN ["/bin/bash", "-l", "-c", "cd /usr/src/app; bundle install"]

#Run Redis and tests
CMD ["/bin/bash", "-l", "-c", "redis-server > /dev/null & cd /usr/src/app && bundle exec rake test"]