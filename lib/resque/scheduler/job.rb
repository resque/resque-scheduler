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
        def cron(value = nil)
          return @cron ||= nil if value.nil?
          @cron = value
        end

        def every(value = nil)
          return @every ||= nil if value.nil?
          @every = value
        end

        def queue(value = nil)
          return @queue ||= nil if value.nil?
          @queue = value
        end

        def args(value = nil)
          return @args ||= nil if value.nil?
          @args = value
        end

        def description(value = nil)
          return @description ||= nil if value.nil?
          @description = value
        end
      end
    end
  end
end
