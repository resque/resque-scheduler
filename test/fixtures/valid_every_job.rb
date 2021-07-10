# vim:fileencoding=utf-8

require 'resque/scheduler/job'

class ValidEveryJob
  include Resque::Scheduler::Job

  every '1d'
  queue 'default'
  args 'args'
  description 'description'
end
