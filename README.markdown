resque-scheduler
===============

Resque-scheduler is an extension to [Resque](http://github.com/defunkt/resque)
that adds support for queueing items in the future.

Requires redis >=1.1.


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

A queue option can also be specified. When job will go onto the specified queue
if it is available (Even if @queue is specified in the job class). When the
queue is given it is not necessary for the scheduler to load the class.

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


Resque-web additions
--------------------

Resque-scheduler also adds to tabs to the resque-web UI.  One is for viewing
(and manually queueing) the schedule and one is for viewing pending jobs in
the delayed queue.

The Schedule tab:

![The Schedule Tab](http://img.skitch.com/20100111-km2f5gmtpbq23enpujbruj6mgk.png)

The Delayed tab:

![The Delayed Tab](http://img.skitch.com/20100111-ne4fcqtc5emkcuwc5qtais2kwx.jpg)


Installation and the Scheduler process
--------------------------------------

To install:

    gem install resque-scheduler

You'll need to add this to your rakefile:

    require 'resque_scheduler/tasks'
    task "resque:setup" => :environment

The scheduler process is just a rake task which is responsible for both queueing
items from the schedule and polling the delayed queue for items ready to be
pushed on to the work queues.  For obvious reasons, this process never exits.

    $ rake resque:scheduler 

Supported environment variables are `VERBOSE` and `MUTE`.  If either is set to
any nonempty value, they will take effect.  `VERBOSE` simply dumps more output
to stdout.  `MUTE` does the opposite and silences all output. `MUTE` supercedes
`VERBOSE`.


Plagurism alert
---------------

This was intended to be an extension to resque and so resulted in a lot of the
code looking very similar to resque, particularly in resque-web and the views. I
wanted it to be similar enough that someone familiar with resque could easily
work on resque-scheduler.


Contributing
------------

For bugs or suggestions, please just open an issue in github.
