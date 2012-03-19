## 2.0.0.h (2012-03-19)

* Adding plugin support with hooks (andreas)

## 2.0.0.f (2011-11-03)

* TODO: address race condition with delayed jobs (using redis transactions)
* Support ENV['BACKGROUND'] flag for daemonizing (bernerdschaefer)
* Added support for before_schedule and after_schedule hooks (yaauie)
* Added remove_delayed_job_from_timestamp to remove delayed jobs from
  a given timestamp.

## 2.0.0.e (2011-09-16)

* Adding enqueue_at_with_queue/enqueue_in_with_queue support (niralisse)
* Adding `Resque::Scheduler.poll_sleep_amount` to allow for configuring
  the sleep time b/w delayed queue polls.
* Add a "Clear Delayed Jobs" button to the Delayed Jobs page (john-griffin)
* Fixed pagination issue on the Delayed tab

## 2.0.0.d (2011-04-04)

* porting bug fixes from v1.9-stable

## 2.0.0.c

* Rake task drop a pid file (sreeix)

## 2.0.0.b

* Bug fixes

## 2.0.0.a

* Dynamic schedule support (brianjlandau, davidyang)
* Now depends on redis >=1.3

## 1.9.9 (2011-03-29)

* Compatibility with resque 1.15.0

## 1.9.8 (???)

* Validates delayed jobs prior to insertion into the delayed queue (bogdan)
* Rescue exceptions that occur during queuing and log them (dgrijalva)

## 1.9.7 (2010-11-09)

* Support for rufus-scheduler "every" syntax (fallwith)
* Ability to pass a Time to handle_delayed_items for testing/staging (rcarver)

## 1.9.6 (2010-10-08)

* Support for custom job classes (like resque-status) (mattetti)

## 1.9.5 (2010-09-09)

* Updated scheduler rake task to allow for an alternate setup task
  to avoid loading the entire stack. (chewbranca)
* Fixed sig issue on win32 (#25)

## 1.9.4 (2010-07-29)

* Adding ability to remove jobs from delayed queue (joshsz)
* Fixing issue #23 (removing .present? reference)

## 1.9.3 (2010-07-07)

* Bug fix (#19)

## 1.9.2 (2010-06-16)

* Fixing issue with redis gem 2.0.1 and redis server 1.2.6 (dbackeus)

## 1.9.1 (2010-06-04)

* Fixing issue with redis server 1.2.6 and redis gem 2.0.1

## 1.9.0 (2010-06-04)

* Adding redis 2.0 support (bpo)

## 1.8.2 (2010-06-04)

* Adding queue now functionality to delayed timestamps (daviddoan)

## 1.8.1 (2010-05-19)

* Adding rails_env for scheduled jobs to support scoping jobs by
  RAILS_ENV (gravis).
* Fixing ruby 1.8.6 compatibility issue.
* Adding gemspec for bundler support.

## 1.8.0 (2010-04-14)

* Moving version to match corresponding resque version
* Sorting schedule on Scheduler tab
* Adding tests for resque-web (gravis)

## 1.0.5 (2010-03-01)

* Fixed support for overriding queue from schedule config.
* Removed resque-web dependency on loading the job classes for "Queue Now",
  provided "queue" is specified in the schedule.
* The queue is now stored with the job and arguments in the delayed queue so
  there is no longer a need for the scheduler to load job classes to introspect
  the queue.

## 1.0.4 (2010-02-26)

* Added support for specifying the queue to put the job onto. This allows for 
  you to have one job that can go onto multiple queues and be able to schedule
  jobs without having to load the job classes.

## 1.0.3 (2010-02-11)

* Added support for scheduled jobs with empty crons. This is helpful to have
  jobs that you don't want on a schedule, but do want to be able to queue by
  clicking a button.

## 1.0.2 (2010-02-?)

* Change Delayed Job tab to display job details if only 1 job exists
  for a given timestamp

## 1.0.1 (2010-01-?)

* Bugfix: delayed jobs close together resulted in a 5 second sleep

