# vim:fileencoding=utf-8

module Resque
  module Scheduler
    module Lock
      class Base
        attr_reader :key
        attr_accessor :timeout

        def initialize(key, options = {})
          @key = key

          # 3 minute default timeout
          @timeout = options[:timeout] || Resque::Scheduler.lock_timeout
        end

        # Attempts to acquire the lock. Returns true if successfully acquired.
        def acquire!
          raise NotImplementedError
        end

        def value
          @value ||= [hostname, process_id].join(':')
        end

        # Returns true if you currently hold the lock.
        def locked?
          raise NotImplementedError
        end

        # Releases the lock.
        def release!
          Resque.redis.del(key) == 1
        end

        # Releases the lock iff we own it
        def release
          locked? && release!
        end

        private

        # Extends the lock by `timeout` seconds.
        def extend_lock!
          Resque.redis.expire(key, timeout)
        end

        def hostname
          local_hostname = Socket.gethostname
          Addrinfo.getaddrinfo(local_hostname, 'http').first.getnameinfo.first
        rescue
          local_hostname
        end

        def process_id
          Process.pid
        end
      end
    end
  end
end
