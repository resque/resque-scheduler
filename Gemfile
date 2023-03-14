# vim:fileencoding=utf-8
source 'https://rubygems.org'

case resque_version = ENV.fetch('RESQUE', 'master')
when 'master'
  gem 'resque', git: 'https://github.com/resque/resque'
else
  gem 'resque', resque_version
end

case rufus_scheduler_version = ENV.fetch('RUFUS_SCHEDULER', '3.6')
when 'master'
  gem 'rufus-scheduler', git: 'https://github.com/jmettraux/rufus-scheduler'
else
  gem 'rufus-scheduler', rufus_scheduler_version
end

case redis_version = ENV.fetch('REDIS_VERSION', 'latest')
when 'master'
  gem 'redis', git: 'https://github.com/redis/redis-rb'
when 'latest'
  gem 'redis'
else
  gem 'redis', redis_version
end

gem 'sinatra', '> 2.0'

gemspec
