require 'rubygems'
require 'resque'
require 'resque/server'
require 'resque_scheduler/version'
require 'resque/scheduler'
require 'resque_scheduler/server'

module ResqueScheduler

  #
  # Accepts a new schedule configuration of the form:
  #
  #   {some_name => {"cron" => "5/* * * *",
  #                  "class" => DoSomeWork,
  #                  "args" => "work on this string",
  #                  "description" => "this thing works it"s butter off"},
  #    ...}
  #
  # :name can be anything and is used only to describe the scheduled job
  # :cron can be any cron scheduling string :job can be any resque job class
  # :class must be a resque worker class
  # :args can be any yaml which will be converted to a ruby literal and passed
  #   in a params. (optional)
  # :description is just that, a description of the job (optional). If params is
  #   an array, each element in the array is passed as a separate param,
  #   otherwise params is passed in as the only parameter to perform.
  def schedule=(schedule_hash)
    @schedule = schedule_hash
  end

  # Returns the schedule hash
  def schedule
    @schedule ||= {}
  end

end

Resque.extend ResqueScheduler
Resque::Server.class_eval do
  include ResqueScheduler::Server
end