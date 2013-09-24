resque-scheduler
================

[![Dependency Status](https://gemnasium.com/resque/resque-scheduler.png)](https://gemnasium.com/resque/resque-scheduler)
[![Gem Version](https://badge.fury.io/rb/resque-scheduler.png)](http://badge.fury.io/rb/resque-scheduler)
[![Build Status](https://travis-ci.org/resque/resque-scheduler.png?branch=master)](https://travis-ci.org/resque/resque-scheduler)

### Description

Resque-scheduler is an extension to [Resque](http://github.com/resque/resque)
that adds support for queueing items in the future.

This table explains the version requirements for redis

| resque-scheduler version | required redis version|
|:-------------------------|----------------------:|
| >= 2.0.0                 | >= 2.2.0              |
| >= 0.0.1                 | >= 1.3                |


Job scheduling is supported in two different way: Recurring (scheduled) and
Delayed.

Scheduled jobs are like cron jobs, recurring on a regular basis.  Delayed
jobs are resque jobs that you want to run at some point in the future.
The syntax is pretty explanatory:

```ruby
Resque.enqueue_in(5.days, SendFollowupEmail) # run a job in 5 days
# or
Resque.enqueue_at(5.days.from_now, SomeJob) # run SomeJob at a specific time
```

### Documentation

This README covers what most people need to know.  If you're looking for
details on individual methods, you might want to try the [rdoc](http://rdoc.info/github/bvandenbos/resque-scheduler/master/frames).

### Installation

To install:

    gem install resque-scheduler

If you use a Gemfile, you may want to specify the `:require` explicitly:

```ruby
gem 'resque-scheduler', :require => 'resque_scheduler'
```

Adding the resque:scheduler rake task:

```ruby
require 'resque_scheduler/tasks'
```

There are three things `resque-scheduler` needs to know about in order to do
it's jobs: the schedule, where redis lives, and which queues to use.  The
easiest way to configure these things is via the rake task.  By default,
`resque-scheduler` depends on the "resque:setup" rake task.  Since you
probably already have this task, lets just put our configuration there.
`resque-scheduler` pretty much needs to know everything `resque` needs
to know.

```ruby
# Resque tasks
require 'resque/tasks'
require 'resque_scheduler/tasks'

namespace :resque do
  task :setup do
    require 'resque'
    require 'resque_scheduler'
    require 'resque/scheduler'

    # you probably already have this somewhere
    Resque.redis = 'localhost:6379'

    # If you want to be able to dynamically change the schedule,
    # uncomment this line.  A dynamic schedule can be updated via the
    # Resque::Scheduler.set_schedule (and remove_schedule) methods.
    # When dynamic is set to true, the scheduler process looks for
    # schedule changes and applies them on the fly.
    # Note: This feature is only available in >=2.0.0.
    #Resque::Scheduler.dynamic = true

    # The schedule doesn't need to be stored in a YAML, it just needs to
    # be a hash.  YAML is usually the easiest.
    Resque.schedule = YAML.load_file('your_resque_schedule.yml')

    # If your schedule already has +queue+ set for each job, you don't
    # need to require your jobs.  This can be an advantage since it's
    # less code that resque-scheduler needs to know about. But in a small
    # project, it's usually easier to just include you job classes here.
    # So, something like this:
    require 'jobs'
  end
end
```

The scheduler process is just a rake task which is responsible for both
queueing items from the schedule and polling the delayed queue for items
ready to be pushed on to the work queues.  For obvious reasons, this process
never exits.

    $ rake resque:scheduler

Supported environment variables are `VERBOSE` and `MUTE`.  If either is set to
any nonempty value, they will take effect.  `VERBOSE` simply dumps more output
to stdout.  `MUTE` does the opposite and silences all output. `MUTE`
supersedes `VERBOSE`.


### Delayed jobs

Delayed jobs are one-off jobs that you want to be put into a queue at some point
in the future.  The classic example is sending email:

```ruby
Resque.enqueue_in(5.days, SendFollowUpEmail, :user_id => current_user.id)
```

This will store the job for 5 days in the resque delayed queue at which time
the scheduler process will pull it from the delayed queue and put it in the
appropriate work queue for the given job and it will be processed as soon as
a worker is available (just like any other resque job).

NOTE: The job does not fire **exactly** at the time supplied.  Rather, once that
time is in the past, the job moves from the delayed queue to the actual resque
work queue and will be completed as workers as free to process it.

Also supported is `Resque.enqueue_at` which takes a timestamp to queue the
job, and `Resque.enqueue_at_with_queue` which takes both a timestamp and a
queue name.

The delayed queue is stored in redis and is persisted in the same way the
standard resque jobs are persisted (redis writing to disk). Delayed jobs differ
from scheduled jobs in that if your scheduler process is down or workers are
down when a particular job is supposed to be queue, they will simply "catch up"
once they are started again.  Jobs are guaranteed to run (provided they make it
into the delayed queue) after their given queue_at time has passed.

One other thing to note is that insertion into the delayed queue is O(log(n))
since the jobs are stored in a redis sorted set (zset).  I can't imagine this
being an issue for someone since redis is stupidly fast even at log(n), but full
disclosure is always best.

#### Removing Delayed jobs

If you have the need to cancel a delayed job, you can do like so:

```ruby
# after you've enqueued a job like:
Resque.enqueue_at(5.days.from_now, SendFollowUpEmail, :user_id => current_user.id)
# remove the job with exactly the same parameters:
Resque.remove_delayed(SendFollowUpEmail, :user_id => current_user.id)
```

### Scheduled Jobs (Recurring Jobs)

Scheduled (or recurring) jobs are logically no different than a standard cron
job.  They are jobs that run based on a fixed schedule which is set at
startup.

The schedule is a list of Resque worker classes with arguments and a
schedule frequency (in crontab syntax).  The schedule is just a hash, but
is most likely stored in a YAML like so:

```yaml
CancelAbandonedOrders:
  cron: "*/5 * * * *"

queue_documents_for_indexing:
  cron: "0 0 * * *"
  # you can use rufus-scheduler "every" syntax in place of cron if you prefer
  # every: 1hr
  # By default the job name (hash key) will be taken as worker class name.
  # If you want to have a different job name and class name, provide the 'class' option
  class: QueueDocuments
  queue: high
  args:
  description: "This job queues all content for indexing in solr"

clear_leaderboards_contributors:
  cron: "30 6 * * 1"
  class: ClearLeaderboards
  queue: low
  args: contributors
  description: "This job resets the weekly leaderboard for contributions"
```

The queue value is optional, but if left unspecified resque-scheduler will
attempt to get the queue from the job class, which means it needs to be
defined.  If you're getting "uninitialized constant" errors, you probably
need to either set the queue in the schedule or require your jobs in your
"resque:setup" rake task.

You can provide options to "every" or "cron" via Array:

```yaml
clear_leaderboards_moderator:
  every:
    - "30s"
    - :first_in: "120s"
  class: CheckDaemon
  queue: daemons
  description: "This job will check Daemon every 30 seconds after 120 seconds after start"
```

NOTE: Six parameter cron's are also supported (as they supported by
rufus-scheduler which powers the resque-scheduler process).  This allows you
to schedule jobs per second (ie: `"30 * * * * *"` would fire a job every 30
seconds past the minute).

A big shout out to [rufus-scheduler](http://github.com/jmettraux/rufus-scheduler)
for handling the heavy lifting of the actual scheduling engine.


#### Time zones

Note that if you use the cron syntax, this will be interpreted as in the server time zone
rather than the `config.time_zone` specified in Rails.

You can explicitly specify the time zone that rufus-scheduler will use:

```yaml
cron: "30 6 * * 1 Europe/Stockholm"
```

Also note that `config.time_zone` in Rails allows for a shorthand (e.g. "Stockholm")
that rufus-scheduler does not accept. If you write code to set the scheduler time zone
from the `config.time_zone` value, make sure it's the right format, e.g. with:

```ruby
ActiveSupport::TimeZone.find_tzinfo(Rails.configuration.time_zone).name
```

A future version of resque-scheduler may do this for you.

#### Hooks

Similar to the `before_enqueue`- and `after_enqueue`-hooks provided in Resque
(>= 1.19.1), your jobs can specify one or more of the following hooks:

* `before_schedule`: Called with the job args before a job is placed on
  the delayed queue. If the hook returns `false`, the job will not be placed on
  the queue.
* `after_schedule`: Called with the job args after a job is placed on the
  delayed queue. Any exception raised propagates up to the code with queued the
  job.
* `before_delayed_enqueue`: Called with the job args after the job has been
  removed from the delayed queue, but not yet put on a normal queue. It is
  called before `before_enqueue`-hooks, and on the same job instance as the
  `before_enqueue`-hooks will be invoked on. Return values are ignored.

#### Support for resque-status (and other custom jobs)

Some Resque extensions like
[resque-status](http://github.com/quirkey/resque-status) use custom job
classes with a slightly different API signature.  Resque-scheduler isn't
trying to support all existing and future custom job classes, instead it
supports a schedule flag so you can extend your custom class and make it
support scheduled job.

Let's pretend we have a `JobWithStatus` class called `FakeLeaderboard`

```ruby
class FakeLeaderboard < Resque::JobWithStatus
  def perform
    # do something and keep track of the status
  end
end
```

And then a schedule:

```yaml
create_fake_leaderboards:
  cron: "30 6 * * 1"
  queue: scoring
  custom_job_class: FakeLeaderboard
  args:
  rails_env: demo
  description: "This job will auto-create leaderboards for our online demo and the status will update as the worker makes progress"
```

If your extension doesn't support scheduled job, you would need to extend the
custom job class to support the #scheduled method:

```ruby
module Resque
  class JobWithStatus
    # Wrapper API to forward a Resque::Job creation API call into
    # a JobWithStatus call.
    def self.scheduled(queue, klass, *args)
      create(*args)
    end
  end
end
```

### Redundancy and Fail-Over

*>= 2.0.1 only.  Prior to 2.0.1, it is not recommended to run multiple resque-scheduler processes and will result in duplicate jobs.*

You may want to have resque-scheduler running on multiple machines for
redudancy.  Electing a master and failover is built in and default.  Simply
run resque-scheduler on as many machine as you want pointing to the same
redis instance and schedule.  The scheduler processes will use redis to
elect a master process and detect failover when the master dies.  Precautions are
taken to prevent jobs from potentially being queued twice during failover even
when the clocks of the scheduler machines are slightly out of sync (or load affects
scheduled job firing time).  If you want the gory details, look at Resque::SchedulerLocking.

If the scheduler process(es) goes down for whatever reason, the delayed items
that should have fired during the outage will fire once the scheduler process
is started back up again (regardless of it being on a new machine).  Missed
scheduled jobs, however, will not fire upon recovery of the scheduler process.
Think of scheduled (recurring) jobs as cron jobs - if you stop cron, it doesn't fire
missed jobs once it starts back up.

You might want to share a redis instance amongst multiple Rails applications with different
scheduler with different config yaml files. If this is the case, normally, only one will ever
run, leading to undesired behaviour. To allow different scheduler configs run at the same time
on one redis, you can either namespace your redis connections, or supply an environment variable
to split the shared lock key resque-scheduler uses thus:

    RESQUE_SCHEDULER_MASTER_LOCK_PREFIX=MyApp: rake resque:scheduler

### resque-web Additions

Resque-scheduler also adds to tabs to the resque-web UI.  One is for viewing
(and manually queueing) the schedule and one is for viewing pending jobs in
the delayed queue.

The Schedule tab:

![The Schedule Tab](https://f.cloud.github.com/assets/45143/1178456/c99e5568-21b0-11e3-8c57-e1305d0ee8ef.png)

The Delayed tab:

![The Delayed Tab](http://img.skitch.com/20100111-ne4fcqtc5emkcuwc5qtais2kwx.jpg)

#### How do I get the schedule tabs to show up???

To get these to show up you need to pass a file to `resque-web` to tell it to
include the `resque-scheduler` plugin and the resque-schedule server extension
to the resque-web sinatra app.  Unless you're running redis on localhost, you
probably already have this file.  It probably looks something like this:

```ruby
require 'resque' # include resque so we can configure it
Resque.redis = "redis_server:6379" # tell Resque where redis lives
```

Now, you want to add the following:

```ruby
# This will make the tabs show up.
require 'resque_scheduler'
require 'resque_scheduler/server'
```

That should make the scheduler tabs show up in `resque-web`.


#### Changes as of 2.0.0

As of resque-scheduler 2.0.0, it's no longer necessary to have the resque-web
process aware of the schedule because it reads it from redis.  But prior to
2.0, you'll want to make sure you load the schedule in this file as well.
Something like this:

```ruby
Resque.schedule = YAML.load_file(File.join(RAILS_ROOT, 'config/resque_schedule.yml')) # load the schedule
```

Now make sure you're passing that file to resque-web like so:

    resque-web ~/yourapp/config/resque_config.rb


### Running in the background

(Only supported with ruby >= 1.9). There are scenarios where it's helpful for
the resque worker to run itself in the background (usually in combination with
PIDFILE).  Use the BACKGROUND option so that rake will return as soon as the
worker is started.

    $ PIDFILE=./resque-scheduler.pid BACKGROUND=yes \
        rake resque:scheduler


### Logging

There are several options to toggle the way scheduler logs its actions. They
are toggled by environment variables:

  - `MUTE` will stop logging anything. Completely silent;
  - `VERBOSE` opposite to 'mute' will log even debug information;
  - `LOGFILE` specifies the file to write logs to. Default is standard output.

All those variables are non-mandatory and default values are

```ruby
Resque::Scheduler.mute    = false
Resque::Scheduler.verbose = false
Resque::Scheduler.logfile = nil # that means, all messages go to STDOUT
```


### Polling frequency

You can pass an INTERVAL option which is a integer representing the polling frequency.
The default is 5 seconds, but for a semi-active app you may want to use a smaller (integer) value.

    $ INTERVAL=1 rake resque:scheduler

### Plagiarism alert

This was intended to be an extension to resque and so resulted in a lot of the
code looking very similar to resque, particularly in resque-web and the views. I
wanted it to be similar enough that someone familiar with resque could easily
work on resque-scheduler.


### Contributing

See [CONTRIBUTING.md](CONTRIBUTING.md)

### Authors

See [AUTHORS.md](AUTHORS.md)

### License

See [LICENSE](LICENSE)
