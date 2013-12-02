# vim:fileencoding=utf-8

require 'resque'

redis_env_var = ENV['REDIS_PROVIDER'] || 'REDIS_URL'
Resque.redis = ENV[redis_env_var] || 'localhost:6379'

require 'resque_scheduler'
require 'resque_scheduler/server'
