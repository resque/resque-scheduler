# vim:fileencoding=utf-8
require 'resque-scheduler'
require 'resque/server'
require 'tilt/erb'
require 'json'

# Extend Resque::Server to add tabs
module Resque
  module Scheduler
    module Server
      TIMESTAMP_FORMAT = '%Y-%m-%d %H:%M:%S %z'.freeze

      unless defined?(::Resque::Scheduler::Server::VIEW_PATH)
        VIEW_PATH = File.join(File.dirname(__FILE__), 'server', 'views')
      end

      def self.included(base)
        base.class_eval do
          helpers { include HelperMethods }
          include ServerMethods

          get('/schedule') { schedule }
          post('/schedule/requeue') { schedule_requeue }
          post('/schedule/requeue_with_params') do
            schedule_requeue_with_params
          end
        end
      end

      module ServerMethods
        def schedule
          Resque.reload_schedule! if Resque::Scheduler.dynamic
          erb scheduler_template('scheduler')
        end

        def schedule_requeue
          @job_name = params['job_name'] || params[:job_name]
          config = Resque.schedule[@job_name]
          @parameters = config['parameters'] || config[:parameters]
          if @parameters
            erb scheduler_template('requeue-params')
          else
            Resque::Scheduler.enqueue_from_config(config)
            redirect u('/overview')
          end
        end

        def schedule_requeue_with_params
          job_name = params['job_name'] || params[:job_name]
          config = Resque.schedule[job_name]
          # Build args hash from post data (removing the job name)
          submitted_args = params.reject do |key, _value|
            key == 'job_name' || key == :job_name
          end

          # Merge constructed args hash with existing args hash for
          # the job, if it exists
          config_args = config['args'] || config[:args] || {}
          config_args = config_args.merge(submitted_args)

          # Insert the args hash into config and queue the resque job
          config = config.merge('args' => config_args)
          Resque::Scheduler.enqueue_from_config(config)
          redirect u('/overview')
        end
      end

      module HelperMethods
        def format_time(t)
          t.strftime(::Resque::Scheduler::Server::TIMESTAMP_FORMAT)
        end

        def show_job_arguments(args)
          Array(args).map(&:inspect).join("\n")
        end

        def queue_from_class_name(class_name)
          Resque.queue_from_class(
            Resque::Scheduler::Util.constantize(class_name)
          )
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

        def schedule_interval_every(every)
          every = [*every]
          s = 'every: ' << every.first

          return s unless every.length > 1

          s << ' ('
          meta = every.last.map do |key, value|
            "#{key.to_s.tr('_', ' ')} #{value}"
          end
          s << meta.join(', ') << ')'
        end

        def schedule_class(config)
          if config['class'].nil? && !config['custom_job_class'].nil?
            config['custom_job_class']
          else
            config['class']
          end
        end

        def scheduler_template(name)
          File.read(
            File.expand_path("../server/views/#{name}.erb", __FILE__)
          )
        end

        def scheduled_in_this_env?(name)
          return true if rails_env(name).nil?
          rails_env(name).split(/[\s,]+/).include?(Resque::Scheduler.env)
        end

        def rails_env(name)
          Resque.schedule[name]['rails_env'] || Resque.schedule[name]['env']
        end

        def scheduler_view(filename, options = {}, locals = {})
          source = File.read(File.join(VIEW_PATH, "#{filename}.erb"))
          erb source, options, locals
        end
      end
    end
  end
end

Resque::Server.tabs << 'Schedule'
Resque::Server.tabs << 'Delayed'

Resque::Server.class_eval do
  include Resque::Scheduler::Server
end
