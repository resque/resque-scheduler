resque-scheduler
===============

Resque-scheduler is basically the union of rufus-scheduler and resque.  The goal
is to provide simple job scheduling with centralized configuration and
distributed workers.  

The schedule is a list of Resque worker classes with arguments and a
schedule frequency (in crontab syntax).  The schedule is just a hash, but
is most likely stored in a YAML:

    queue_documents_for_indexing:
      cron: "0 0 * * *"
      class: QueueDocuments
      args: 
      description: "This job queues all content for indexing in solr

    clear_leaderboards_contributors:
      cron: "30 6 * * 1"
      class: ClearLeaderboards
      args: contributors
      description: "This job resets the weekly leaderboard for contributions"

    clear_leaderboards_moderator:
      cron: "30 6 * * 1"
      class: ClearLeaderboards
      args: moderators
      description: "This job resets the weekly leaderboard for moderators"

And then set the schedule wherever you configure Resque, like so:

    require 'resque-scheduler'
    ResqueScheduler.schedule = YAML.load_file(File.join(File.dirname(__FILE__), '../resque_schedule.yml'))

The scheduler process is just a rake task which adds things to resque when they fire
based on the schedule.  For obvious reasons, this process never exits.

    $ rake resque-scheduler 

You'll need to add this to your rakefile:

    require 'resque_scheduler/tasks'
    task "resque:setup" => :environment


