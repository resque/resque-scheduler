# vim:fileencoding=utf-8

require 'resque/scheduler/job'

class ValidEveryJob
  include Resque::Scheduler::Job

  @queue = :default

  resque_schedule every: '1d', args: 'args', description: 'description'
end
