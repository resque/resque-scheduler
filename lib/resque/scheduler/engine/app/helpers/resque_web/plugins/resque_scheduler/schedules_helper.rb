module ResqueWeb
  module Plugins
    module ResqueScheduler
      module SchedulesHelper
        def scheduled_in_this_env?(name)
          return true if Resque.schedule[name]['rails_env'].nil?
          rails_env(name).split(/[\s,]+/).include?(Resque::Scheduler.env)
        end

        def rails_env(name)
          Resque.schedule[name]['rails_env']
        end

        def schedule_interval_every(every)
          every = [*every]
          s = 'every: ' << every.first

          return s unless every.length > 1

          s << ' ('
          meta = every.last.map do |key, value|
            "#{key.to_s.gsub(/_/, ' ')} #{value}"
          end
          s << meta.join(', ') << ')'
        end

        def schedule_interval(config)
          if config['every']
            schedule_interval_every(config['every'])
          elsif config['cron']
            'cron: ' + config['cron'].to_s
          else
            'Not currently scheduled'
          end
        end

        def schedule_class(config)
          if config['class'].nil? && !config['custom_job_class'].nil?
            config['custom_job_class']
          else
            config['class']
          end
        end

        def queue_from_class_name(class_name)
          Resque.queue_from_class(
              Resque::Scheduler::Util.constantize(class_name)
          )
        end
      end
    end
  end
end
