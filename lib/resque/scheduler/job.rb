# vim:fileencoding=utf-8

module Resque
  module Scheduler
    module Job
      class << self
        def included(base)
          base.extend ClassMethods
        end
      end

      module ClassMethods
        def resque_schedule(cron: nil, every: nil, args: nil, description: nil)
          Resque::Scheduler.load_schedule_job(
            name,
            'class' => name,
            'cron' => cron,
            'every' => every,
            'queue' => @queue,
            'args' => args,
            'description' => description
          )
        end
      end
    end
  end
end
