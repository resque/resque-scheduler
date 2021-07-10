# vim:fileencoding=utf-8

require 'resque/scheduler/job'

class ValidCronJob
  include Resque::Scheduler::Job

  cron '*/2 * * * *'
  queue 'default'
  args 'args'
  description 'description'
end
