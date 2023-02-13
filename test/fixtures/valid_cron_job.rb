# vim:fileencoding=utf-8

require 'resque/scheduler/job'

class ValidCronJob
  include Resque::Scheduler::Job

  @queue = :default

  resque_schedule cron: '*/2 * * * *', args: 'args', description: 'description'
end
