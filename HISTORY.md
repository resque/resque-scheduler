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

