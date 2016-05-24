# vim:fileencoding=utf-8

require 'json'
require 'yaml'
require 'resque'

redis_env_var = ENV['REDIS_PROVIDER'] || 'REDIS_URL'
Resque.redis = ENV[redis_env_var] || 'localhost:6379'

require 'resque-scheduler'
require 'resque/scheduler/server'

schedule_yml = ENV['RESQUE_SCHEDULE_YML']
if schedule_yml
  Resque.schedule = if File.exist?(schedule_yml)
                      YAML.load_file(schedule_yml)
                    else
                      YAML.load(schedule_yml)
                    end
end

schedule_json = ENV['RESQUE_SCHEDULE_JSON']
if schedule_json
  Resque.schedule = if File.exist?(schedule_json)
                      JSON.parse(File.read(schedule_json))
                    else
                      JSON.parse(schedule_json)
                    end
end

class Putter
  @queue = 'putting'

  def self.perform(*args)
    args.each { |arg| puts arg }
  end
end
