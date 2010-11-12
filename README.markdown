resque-scheduler
===============

Resque-scheduler is an extension to [Resque](http://github.com/defunkt/resque)
that adds support for queueing items in the future.

Requires redis >=1.3.


Job scheduling is supported in two different way:

### Recurring (scheduled)

Recurring (or scheduled) jobs are logically no different than a standard cron
job.  They are jobs that run based on a fixed schedule which is set at startup.

The schedule is a list of Resque worker classes with arguments and a
schedule frequency (in crontab syntax).  The schedule is just a hash, but
is most likely stored in a YAML like so:

    queue_documents_for_indexing:
      cron: "0 0 * * *"
      class: QueueDocuments
      args: 
      description: "This job queues all content for indexing in solr"

    clear_leaderboards_contributors:
      cron: "30 6 * * 1"
      class: ClearLeaderboards
      args: contributors
      description: "This job resets the weekly leaderboard for contributions"

A queue option can also be specified. Then the job will go onto the specified
queue if it is available (Even if @queue is specified in the job class). When
the queue is given it is not necessary for the scheduler to load the class.

    clear_leaderboards_moderator:
      cron: "30 6 * * 1"
      class: ClearLeaderboards
      queue: scoring
      args: moderators
      description: "This job resets the weekly leaderboard for moderators"

And then set the schedule wherever you configure Resque, like so:

    require 'resque_scheduler'
    Resque.schedule = YAML.load_file(File.join(File.dirname(__FILE__), '../resque_schedule.yml'))

Keep in mind, scheduled jobs behave like crons: if your scheduler process (more
on that later) is not running when a particular job is supposed to be queued,
it will NOT be ran later when the scheduler process is started back up.  In that
sense, you can sort of think of the scheduler process as crond.  Delayed jobs,
however, are different.

A big shout out to [rufus-scheduler](http://github.com/jmettraux/rufus-scheduler)
for handling the heavy lifting of the actual scheduling engine.

### Delayed jobs

Delayed jobs are one-off jobs that you want to be put into a queue at some point
in the future.  The classic example is sending email:

    Resque.enqueue_at(5.days.from_now, SendFollowUpEmail, :user_id => current_user.id)

This will store the job for 5 days in the resque delayed queue at which time the
scheduler process will pull it from the delayed queue and put it in the
appropriate work queue for the given job and it will be processed as soon as
a worker is available.

NOTE: The job does not fire **exactly** at the time supplied.  Rather, once that
time is in the past, the job moves from the delayed queue to the actual resque
work queue and will be completed as workers as free to process it.

Also supported is `Resque.enqueue_in` which takes an amount of time in seconds
in which to queue the job.

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

*Removing Delayed jobs*

If you have the need to cancel a delayed job, you can do so thusly:

    # after you've enqueued a job like:
    Resque.enqueue_at(5.days.from_now, SendFollowUpEmail, :user_id => current_user.id)
    # remove the job with exactly the same parameters:
    Resque.remove_delayed(SendFollowUpEmail, :user_id => current_user.id)

### Schedule jobs per environment

Resque-Scheduler allows to create schedule jobs for specific envs.  The arg
`rails_env` (optional) can be used to determine which envs are concerned by the
job:

    create_fake_leaderboards:
      cron: "30 6 * * 1"
      class: CreateFakeLeaderboards
      queue: scoring
      args: 
      rails_env: demo
      description: "This job will auto-create leaderboards for our online demo"

The scheduled job create_fake_leaderboards will be created only if the
environment variable `RAILS_ENV` is set to demo:

    $ RAILS_ENV=demo rake resque:scheduler 

NOTE: If you have added the 2 lines bellow to your Rails Rakefile 
(ie: lib/tasks/resque-scheduler.rake), the rails env is loaded automatically
and you don't have to specify RAILS_ENV if the var is correctly set in
environment.rb

Alternatively, you can use your resque initializer to avoid loading the entire
rails stack.

    $ rake resque:scheduler INITIALIZER_PATH=config/initializers/resque.rb


Multiple envs are allowed, separated by commas:

    create_fake_leaderboards:
      cron: "30 6 * * 1"
      class: CreateFakeLeaderboards
      queue: scoring
      args: 
      rails_env: demo, staging, production
      description: "This job will auto-create leaderboards"

NOTE: If you specify the `rails_env` arg without setting RAILS_ENV as an 
environment variable, the job won't be loaded.

### Dynamic Schedules

If needed you can also have recurring jobs (scheduled) that are dynamically
defined and updated inside of your application.  A good example is if you want
to allow users to configured when a report is automatically generated.  This
can be completed by loading the schedule initially wherever you configure
Resque and setting `Resque::Scheduler.dynamic` to `true`. Then subsequently
updating the "`schedules`" key in redis, namespaced to the Resque namespace.
The "`schedules`" key is expected to be a redis hash data type, where the key
is the name of the schedule and the value is a JSON encoded hash of the
schedule configuration.

When the scheduler loops it will look for differences between the existing
schedule and the current schedule in redis. If there are differences it will
make the necessary changes to the running schedule. The schedule names that
need to be changed are stored in the `schedules_changed` set in redis.

To force the scheduler to reload the schedule you just send it the `USR2`
signal.  This will force a complete schedule reload (unscheduling and
rescheduling everything).

To add/update, delete, and retrieve individual schedule items you should
use the provided API methods:

* `Resque.set_schedule(name, config)`
* `Resque.get_schedule(name)`
* `Resque.remove_schedule(name)`

For example:

    Resque.set_schedule("create_fake_leaderboards", {
      :cron => "30 6 * * 1",
      :class => "CreateFakeLeaderboards",
      :queue => scoring
    })

### Support for customized Job classes

Some Resque extensions like
[resque-status](http://github.com/quirkey/resque-status) use custom job
classes with a slightly different API signature.  Resque-scheduler isn't
trying to support all existing and future custom job classes, instead it
supports a schedule flag so you can extend your custom class and make it
support scheduled job.

Let's pretend we have a JobWithStatus class called FakeLeaderboard

		class FakeLeaderboard < Resque::JobWithStatus
			def perfom
				# do something and keep track of the status
			end
		end

    create_fake_leaderboards:
      cron: "30 6 * * 1"
      queue: scoring
      custom_job_class: FakeLeaderboard
      args: 
      rails_env: demo
      description: "This job will auto-create leaderboards for our online demo and the status will update as the worker makes progress"

If your extension doesn't support scheduled job, you would need to extend the
custom job class to support the #scheduled method:

    module Resque
      class JobWithStatus
        # Wrapper API to forward a Resque::Job creation API call into
        # a JobWithStatus call.
        def self.scheduled(queue, klass, *args)
          create(args)
        end
      end
    end


Resque-web additions
--------------------

Resque-scheduler also adds to tabs to the resque-web UI.  One is for viewing
(and manually queueing) the schedule and one is for viewing pending jobs in
the delayed queue.

The Schedule tab:

![The Schedule Tab](http://img.skitch.com/20100111-km2f5gmtpbq23enpujbruj6mgk.png)

The Delayed tab:

![The Delayed Tab](http://img.skitch.com/20100111-ne4fcqtc5emkcuwc5qtais2kwx.jpg)

Get get these to show up you need to pass a file to `resque-web` to tell it to
include the `resque-scheduler` plugin.  You probably already have a file
somewhere where you configure `resque`.  It probably looks something like this:

    require 'resque' # include resque so we can configure it
    Resque.redis = "redis_server:6379" # tell Resque where redis lives

Now, you want to add the following:

    require 'resque_scheduler' # include the resque_scheduler (this makes the tabs show up)

As of resque-scheduler 2.0, it's no longer necessary to have the resque-web
process aware of the schedule because it reads it from redis.  But prior to
2.0, you'll want to make sure you load the schedule in this file as well.
Something like this:

    Resque.schedule = YAML.load_file(File.join(RAILS_ROOT, 'config/resque_schedule.yml')) # load the schedule

Now make sure you're passing that file to resque-web like so:

    resque-web ~/yourapp/config/resque_config.rb

That should make the scheduler tabs show up in `resque-web`.


Installation and the Scheduler process
--------------------------------------

To install:

    gem install resque-scheduler

The unless you specify the `queue` for each scheduled job, the scheduler 
needs to know about your job classes (so it can put them into the appropriate
queue).  To do so, extend the "resque:scheduler_setup" to load your app's code.
In rails, it would look something like this:

    require 'resque_scheduler/tasks'
    task "resque:scheduler_setup" => :environment # load the env so we know about the job classes

By default, "resque:scheduler_setup" invokes "resque:setup".

The scheduler process is just a rake task which is responsible for both queueing
items from the schedule and polling the delayed queue for items ready to be
pushed on to the work queues.  For obvious reasons, this process never exits.

    $ rake resque:scheduler 

Supported environment variables are `VERBOSE` and `MUTE`.  If either is set to
any nonempty value, they will take effect.  `VERBOSE` simply dumps more output
to stdout.  `MUTE` does the opposite and silences all output. `MUTE` supersedes
`VERBOSE`.

NOTE: You DO NOT want to run >1 instance of the scheduler.  Doing so will result
in the same job being queued more than once.  You only need one instnace of the
scheduler running per resque instance (regardless of number of machines).


Plagurism alert
---------------

This was intended to be an extension to resque and so resulted in a lot of the
code looking very similar to resque, particularly in resque-web and the views. I
wanted it to be similar enough that someone familiar with resque could easily
work on resque-scheduler.


Contributing
------------

For bugs or suggestions, please just open an issue in github.
