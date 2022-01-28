# vim:fileencoding=utf-8
require_relative 'base'

module Resque
  module Scheduler
    module Lock
      class ResilientModern < Resilient
        def acquire!
          Resque.redis.set(key, value, nx: true, ex: timeout)
        end
      end
    end
  end
end
