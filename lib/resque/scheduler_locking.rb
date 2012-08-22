
# ### Locking the scheduler process
#
# There are two places in resque-scheduler that need to be synchonized
# in order to be able to run redundant scheduler processes while ensuring jobs don't 
# get queued multiple times when the master process changes.
# 
# 1) Processing the delayed queues (jobs that are created from enqueue_at/enqueue_in, etc)
# 2) Processing the scheduled (cron-like) jobs from rufus-scheduler
#
# Protecting the delayed queues (#1) is relatively easy.  A simple SETNX in 
# redis would suffice.  However, protecting the scheduled jobs is trickier
# because the clocks on machines could be slightly off or actual firing times
# could vary slightly due to load.  If scheduler A's clock is slightly ahead
# of scheduler B's clock (since they are on different machines), when
# scheduler A dies, we need to ensure that scheduler B doesn't queue jobs
# that A already queued before it's death. (This all assumes that it is
# better to miss a few scheduled jobs than it is to run them multiple times
# for the same iteration.)
#
# To avoid queuing multiple jobs in the case of master fail-over, the master
# should remain the master as long as it can rather than a simple SETNX which
# would result in the master roll being passed around frequently.
#
# Locking Scheme:
# Each resque-scheduler process attempts to get the master lock via SETNX.
# Once obtained, it sets the expiration for 3 minutes (configurable).  The
# master process continually updates the timeout on the lock key to be 3
# minutes in the future in it's loop(s) (see `run`) and when jobs come out of
# rufus-scheduler (see `load_schedule_job`).  That ensures that a minimum of
# 3 minutes must pass since the last queuing operation before a new master is
# chosen.  If, for whatever reason, the master fails to update the expiration
# for 3 minutes, the key expires and the lock is up for grabs.  If
# miraculously the original master comes back to life, it will realize it is
# no longer the master and stop processing jobs.
#
# The clocks on the scheduler machines can then be up to 3 minutes off from
# each other without the risk of queueing the same scheduled job twice during
# a master change.  The catch is, in the event of a master change, no
# scheduled jobs will be queued during those 3 minutes.  So, there is a trade
# off: the higher the timeout, the less likely scheduled jobs will be fired
# twice but greater chances of missing scheduled jobs.  The lower the timeout,
# less likely jobs will be missed, greater the chances of jobs firing twice.  If
# you don't care about jobs firing twice or are certain your machines' clocks
# are well in sync, a lower timeout is preferable.  One thing to keep in mind:
# this only effects *scheduled* jobs - delayed jobs will never be lost or
# skipped since eventually a master will come online and it will process
# everything that is ready (no matter how old it is).  Scheduled jobs work
# like cron - if you stop cron, no jobs fire while it's stopped and it doesn't
# fire jobs that were missed when it starts up again.

module Resque

  module SchedulerLocking

    # The TTL (in seconds) for the master lock
    def lock_timeout=(v)
      @lock_timeout = v
    end

    def lock_timeout
      @lock_timeout ||= 60 * 3 # 3 minutes
    end

    def hostname
      Socket.gethostbyname(Socket.gethostname).first
    end

    def process_id
      Process.pid
    end

    def is_master?
      acquire_master_lock! || has_master_lock?
    end

    def master_lock_value
      [hostname, process_id].join(':')
    end

    def master_lock_key
      :resque_scheduler_master_lock
    end

    def extend_lock!
      # If the master fails to checkin for 3 minutes, the lock is released and is up for grabs
      Resque.redis.expire(master_lock_key, lock_timeout)
    end

    def release_master_lock!
      Resque.redis.del(master_lock_key)
    end

    def acquire_master_lock!
      if Resque.redis.setnx(master_lock_key, master_lock_value)
        extend_lock!
        true
      end
    end

    def has_master_lock?
      if Resque.redis.get(master_lock_key) == master_lock_value
        extend_lock!
        # Since this process could lose the lock between checking
        # if it has it and extending the lock, check again to make 
        # sure it still has it.
        if Resque.redis.get(master_lock_key) == master_lock_value
          true
        end
      end
    end

  end

end