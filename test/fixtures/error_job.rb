# vim:fileencoding=utf-8

require 'resque/scheduler/job'

class ErrorJob
  include Resque::Scheduler::Job
end
