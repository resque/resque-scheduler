# Change Log

**ATTN**: This project uses [semantic versioning](http://semver.org/).

## [Unreleased]
### Changed
- Add support and testing for ruby 2.4
- Change log format and file name
- Drop testing on ruby 1.9.3
- `Lock::Resilient`: Refresh lua script sha if it does not exist in redis server

### Fixed
- Reporting version via `resque-scheduler --version`

## [4.3.0] - 2016-06-26
### Added
- Windows testing on Appveyor
- Code of Conduct

### Changed
- Silence output by default when daemonizing
- Update vagrant setup
- Update gem metadata per latest Bundler defaults

## [4.2.1] - 2016-06-08
### Added
- Docs improvements

### Changed
- Optimization of `find_delayed_selection`
- More defensive code around redis disconnects
- Only trap existing signals on given platform
- RuboCop auto-fixes
- Dependency updates

## [4.2.0] - 2016-04-29
### Added
- Index column to scheduler tab
- Failure hook support for better extensibility

### Changed
- Clean up and simplify the scheduling extension
- Make `Resque::Scheduler.logger` accessible to user
- Default failure handler now outputs stacktrace
- Update rufus-scheduler

### Fixed
- Displaying schedules appropriate to the `env` in scheduler UI
- A race condition in concurrent restarts

## [4.1.0] - 2016-02-10
### Added
- View helper to cut down on repetition
- `Resque.(find|enqueue)_delayed_selection` methods to complement
  `Resque.remove_delayed_selection`

### Changed
- Leave undefined env vars unset in internal options hash
- Insulate checking `Rails.env`
- Documentation updates and typo fixes

### Fixed
- Check thread life only if present

## [4.0.0] - 2014-12-21
### Added
- Show current master in the web UI

### Changed
- Bump rufus-scheduler dependency to `~> 3.0`
- Address warning from redis-namespace related to `#unwatch`
- Documentation updates

### Fixed
- Bugfix related to schedule check when no jobs are in the queue

## [3.1.0] - 2014-12-21
### Added
- Note in README.md about production redis deployment configuration
- Better PID file cleanup
- Option to filter by job class in `Resque.remove_delayed_selection`
- Tell-don't-ask with `Resque.schedule` to enable atomic clear & set

### Changed
- Avoid use of redis `KEYS` command in `Resque.remove_delayed_selection`

### Fixed
- Only release master lock if it belongs to us
- Only override configuration options if provided

## [3.0.0] - 2014-05-27
### Added
- Vagrant setup
- Support for last execution information through the web
- CodeClimate integration
- `Resque.delayed?` and `Resque.next_delayed_schedule`
- Allow scheduled jobs to be deleted via resque web

### Changed
- The grand re-namespacing of `resque_scheduler/(.*)` =&gt;
  `resque/scheduler/\1`
- "Refactoring"
- Cleanup of a ton of rubocop offenses
- Documentation updates
- Handling signals while "sleeping" by relying on `Thread#wakeup`
- Testing against same rubies as resque (+ 2.1.1)
- Renamed `Resque.set_last_run` to `Resque.last_enqueued_at`

### Fixed
- Duplicated layout for `search_form` partial template.
- Issue where Web UI was ONLY showing jobs that only run in the current
  environment

## [2.5.5] - 2014-02-27
### Changed
- Only showing link to job with args if job is present
- Only showing scheduled jobs that match current env or omit env
- Ensuring lock and acquire lua scripts are refreshed on timeout change
- Switch to using `mono_logger` instead of stdlib `logger`

## [2.5.4] - 2014-02-17
### Changed
- Documentation updates

## [2.5.3] - 2014-02-12
### Fixed
- Handling signals during poll sleep

## [2.5.2] - 2014-02-11
### Changed
- Pinning down dependency versions more tightly

## [2.5.1] - 2014-02-09
### Fixed
- Make signal handling (really) Ruby 2 compatible

## [2.5.0] - 2014-02-09
### Added
- Search feature to the Delayed tab in Resque Web

### Changed
- Use `logger.error` when logging errors from `handle_errors`

### Fixed
- Confusion with redis version requirements in `README.md`

## [2.4.0] - 2014-01-14
### Added
- Including optional env and app names in procline
- A standalone `resque-scheduler` executable
- Support for persistence of dynamic schedules
- `.configure` convenience method for block-style configuration
- `.remove_delayed_selection` method to remove based on result of a block
- Support for viewing all schedules for a job in web UI

### Changed
- Bumping the copyright year
- Corrected doc for syntax of class and every keys
- Use resque redis namespace in the master lock key
- Various test improvements, :bug: fixes, and documentation updates!

### Removed
- **POSSIBLE BREAKING CHANGE**: Dropping support for ree

### Fixed
- An explosion regarding `every` in the views
- Unsafe shutdown in Ruby 2

## 2.3.1 (2013-11-20)
### Fixed
- `require_paths` in gemspec

## 2.3.0 (2013-11-07)
### Added
- Add rufus scheduler `every` notice to README
- Specify MIT license in gemspec

### Changed
- **BREAKING CHANGE**: Added `RESQUE_SCHEDULER_INTERVAL` in place of `INTERVAL`
- Use `Float()` instead of `Integer()` to calculate poll sleep amount
- Upgraded dependence of Resque to support 1.25
- Use `Resque.validate` instead of custom `.validate_job!`

### Fixed
- Re-introduced `ThreadError` on Ruby 2

## 2.2.0 (2013-10-13)
### Added
- Support for parameterized resque jobs.
- Allowing prefix for `master_lock_key`.
- `Resque.clean_schedules` method, which is useful when setting up the scheduler
  for the first time.

### Changed
- Locking rufus-scheduler dependency to `~> 2.0`
- Updated redis dependency to `>= 3.0.0`

### Fixed
- Bug fixes related to first time schedule retrieval and missing schedules.

## 2.1.0 (2013-09-20)
### Added
- Add `#scheduled_at` which returns an array of timestamps at which the
  specified job is scheduled
- Add `#enqueue_delayed` for enqueueing specific delayed jobs immediately
- Show server local time in resque-web
- Add support for configuring `Resque::Scheduler.poll_sleep_amount` via the
  `INTERVAL` environmental variable.

### Changed
- Locking to resque &lt; 1.25.0 (for now)
- Syncing stdout/stderr
- Using a logger instead of `#puts`, configurable via `LOGFILE`, `VERBOSE`, and
  `MUTE` environmental variables, as well as being settable via
  `Resque::Scheduler#logger`
- Enqueue immediately if job is being enqueued in the past

### Removed
- Dependency on `Resque::Helpers`

### Fixed
- Ensuring `Resque.schedule=` sets rather than appends
- Process daemonization fixes including stdio redirection and redis client
  reconnection
- Scheduler template when arrays are passed to rufus-scheduler
- Fixed shutdown in ruby 2.0.0

## [2.0.1] - 2013-03-20
### Added
- Locking to support master failover
- Allow custom job classes to be used in `Resque.enqueue_at`
- Allowing `#enqueue_at` to call `#scheduled` when `Resque.inline` is `true`

### Changed
- More efficient `#remove_delayed` implementation

## [2.0.0] - 2012-05-04
### Added
- Support for Resque.inline configuration (carlosantoniodasilva)

### Fixed
- Possible job loss race condition around deleting delayed queues and enqueuing
  a job 0 seconds in the future.

## [2.0.0.h] - 2012-03-19
### Added
- Plugin support with hooks (andreas)

## [2.0.0.f] - 2011-11-03
### Added
- Support `ENV['BACKGROUND']` flag for daemonizing (bernerdschaefer)
- Added support for `before_schedule` and `after_schedule` hooks (yaauie)
- Added `remove_delayed_job_from_timestamp` to remove delayed jobs from
  a given timestamp.

### Fixed
- Address race condition with delayed jobs (using redis transactions)

## [2.0.0.e] - 2011-09-16
### Added
- `enqueue_at_with_queue`/`enqueue_in_with_queue` support (niralisse)
- `Resque::Scheduler.poll_sleep_amount` to allow for configuring
  the sleep time b/w delayed queue polls.
- "Clear Delayed Jobs" button to the Delayed Jobs page (john-griffin)

### Fixed
- Pagination issue on the Delayed tab

## [2.0.0.d] - 2011-04-04
### Changed
- Porting bug fixes from v1.9-stable

## [2.0.0.c] - 2011-03-25
### Changed
- Rake task drop a pid file (sreeix)

## [2.0.0.b] - 2011-02-25
### Fixed
- Bugs

## 2.0.0.a - 2010-12-10
### Added
- Dynamic schedule support (brianjlandau, davidyang)

### Changed
- Now depends on redis >=1.3

## [1.9.11] - 2013-11-20
### Fixed
- Behavior of `#validate_job!` via `#enqueue_at_with_queue` #286
- `require_paths` in gemspec #288

## [1.9.10] - 2013-09-19
### Added
- Backported `#enqueue_at_with_queue`
- Locking to resque &lt; 1.25.0
- Ruby 1.8 compatibility in scheduler tab when schedule keys are symbols

### Changed
- Mocha setup compatibility

## [1.9.9] - 2011-03-29
### Added
- Compatibility with resque 1.15.0

## [1.9.8] - 2011-01-14
### Changed
- Validates delayed jobs prior to insertion into the delayed queue (bogdan)
- Rescue exceptions that occur during queuing and log them (dgrijalva)

## [1.9.7] - 2010-11-09
### Added
- Support for rufus-scheduler "every" syntax (fallwith)
- Ability to pass a Time to `handle_delayed_items` for testing/staging (rcarver)

## [1.9.6] - 2010-10-08
### Added
- Support for custom job classes (like resque-status) (mattetti)

## [1.9.5] - 2010-09-09
### Changed
- Updated scheduler rake task to allow for an alternate setup task
  to avoid loading the entire stack. (chewbranca)

### Fixed
- Sig issue on win32 (#25)

## [1.9.4] - 2010-07-29
### Added
- Ability to remove jobs from delayed queue (joshsz)

### Fixed
- Issue #23 (removing .present? reference)

## [1.9.3] - 2010-07-07
### Fixed
- Bug fix (#19)

## [1.9.2] - 2010-06-16
### Fixed
- Issue with redis gem 2.0.1 and redis server 1.2.6 (dbackeus)

## [1.9.1] - 2010-06-04
### Fixed
- Issue with redis server 1.2.6 and redis gem 2.0.1

## [1.9.0] - 2010-06-04
### Added
- Redis 2.0 support (bpo)

## [1.8.2] - 2010-06-04
### Added
- Queue now functionality to delayed timestamps (daviddoan)

## [1.8.1] - 2010-05-19
### Added
- `rails_env` for scheduled jobs to support scoping jobs by
  `RAILS_ENV` (gravis).
- Adding gemspec for bundler support.

### Fixed
- Ruby 1.8.6 compatibility issue.

## [1.8.0] - 2010-04-14
### Added
- Tests for resque-web (gravis)

### Changed
- Moving version to match corresponding resque version
- Sorting schedule on Scheduler tab

## [1.0.5] - 2010-03-01
### Fixed
- Support for overriding queue from schedule config.

### Changed
- The queue is now stored with the job and arguments in the delayed queue so
  there is no longer a need for the scheduler to load job classes to introspect
  the queue.

### Removed
- resque-web dependency on loading the job classes for "Queue Now", provided
  "queue" is specified in the schedule.

## [1.0.4] - 2010-02-26
### Added
- Support for specifying the queue to put the job onto. This allows for you to
  have one job that can go onto multiple queues and be able to schedule jobs
  without having to load the job classes.

## [1.0.3] - 2010-02-11
### Added
- Support for scheduled jobs with empty crons. This is helpful to have jobs that
  you don't want on a schedule, but do want to be able to queue by clicking a
  button.

## [1.0.2] - 2010-02-10
### Changed
- Delayed Job tab to display job details if only 1 job exists for a given
  timestamp

## [1.0.1] - 2010-02-01
### Fixed
- Delayed jobs close together resulted in a 5 second sleep

## [1.0.0] - 2009-12-21
### Added
- Initial release

[Unreleased]: https://github.com/resque/resque-scheduler/compare/v4.3.0...HEAD
[4.3.0]: https://github.com/resque/resque-scheduler/compare/v4.2.1...v4.3.0
[4.2.1]: https://github.com/resque/resque-scheduler/compare/v4.2.0...v4.2.1
[4.2.0]: https://github.com/resque/resque-scheduler/compare/v4.1.0...v4.2.0
[4.1.0]: https://github.com/resque/resque-scheduler/compare/v4.0.0...v4.1.0
[4.0.0]: https://github.com/resque/resque-scheduler/compare/v3.1.0...v4.0.0
[3.1.0]: https://github.com/resque/resque-scheduler/compare/v3.0.0...v3.1.0
[3.0.0]: https://github.com/resque/resque-scheduler/compare/v2.5.5...v3.0.0
[2.5.5]: https://github.com/resque/resque-scheduler/compare/v2.5.4...v2.5.5
[2.5.4]: https://github.com/resque/resque-scheduler/compare/v2.5.3...v2.5.4
[2.5.3]: https://github.com/resque/resque-scheduler/compare/v2.5.2...v2.5.3
[2.5.2]: https://github.com/resque/resque-scheduler/compare/v2.5.1...v2.5.2
[2.5.1]: https://github.com/resque/resque-scheduler/compare/v2.5.0...v2.5.1
[2.5.0]: https://github.com/resque/resque-scheduler/compare/v2.4.0...v2.5.0
[2.4.0]: https://github.com/resque/resque-scheduler/compare/v2.3.1...v2.4.0
[2.3.1]: https://github.com/resque/resque-scheduler/compare/v2.3.0...v2.3.1
[2.3.0]: https://github.com/resque/resque-scheduler/compare/v2.2.0...v2.3.0
[2.2.0]: https://github.com/resque/resque-scheduler/compare/v2.1.0...v2.2.0
[2.1.0]: https://github.com/resque/resque-scheduler/compare/v2.0.1...v2.1.0
[2.0.1]: https://github.com/resque/resque-scheduler/compare/v2.0.0...v2.0.1
[2.0.0]: https://github.com/resque/resque-scheduler/compare/v2.0.0.h...v2.0.0
[2.0.0.h]: https://github.com/resque/resque-scheduler/compare/v2.0.0.f...v2.0.0.h
[2.0.0.f]: https://github.com/resque/resque-scheduler/compare/v2.0.0.e...v2.0.0.f
[2.0.0.e]: https://github.com/resque/resque-scheduler/compare/v2.0.0.d...v2.0.0.e
[2.0.0.d]: https://github.com/resque/resque-scheduler/compare/v2.0.0.c...v2.0.0.d
[2.0.0.c]: https://github.com/resque/resque-scheduler/compare/61c7b5f...v2.0.0.c
[2.0.0.b]: https://github.com/resque/resque-scheduler/compare/v2.0.0.a...61c7b5f
[1.9.11]: https://github.com/resque/resque-scheduler/compare/v1.9.10...v1.9.11
[1.9.10]: https://github.com/resque/resque-scheduler/compare/v1.9.9...v1.9.10
[1.9.9]: https://github.com/resque/resque-scheduler/compare/v1.9.8...v1.9.9
[1.9.8]: https://github.com/resque/resque-scheduler/compare/v1.9.7...v1.9.8
[1.9.7]: https://github.com/resque/resque-scheduler/compare/v1.9.6...v1.9.7
[1.9.6]: https://github.com/resque/resque-scheduler/compare/v1.9.5...v1.9.6
[1.9.5]: https://github.com/resque/resque-scheduler/compare/v1.9.4...v1.9.5
[1.9.4]: https://github.com/resque/resque-scheduler/compare/v1.9.3...v1.9.4
[1.9.3]: https://github.com/resque/resque-scheduler/compare/v1.9.2...v1.9.3
[1.9.2]: https://github.com/resque/resque-scheduler/compare/v1.9.1...v1.9.2
[1.9.1]: https://github.com/resque/resque-scheduler/compare/v1.9.0...v1.9.1
[1.9.0]: https://github.com/resque/resque-scheduler/compare/v1.8.2...v1.9.0
[1.8.2]: https://github.com/resque/resque-scheduler/compare/v1.8.1...v1.8.2
[1.8.1]: https://github.com/resque/resque-scheduler/compare/v1.8.0...v1.8.1
[1.8.0]: https://github.com/resque/resque-scheduler/compare/v1.0.5...v1.8.0
[1.0.5]: https://github.com/resque/resque-scheduler/compare/v1.0.4...v1.0.5
[1.0.4]: https://github.com/resque/resque-scheduler/compare/v1.0.3...v1.0.4
[1.0.3]: https://github.com/resque/resque-scheduler/compare/v1.0.2...v1.0.3
[1.0.2]: https://github.com/resque/resque-scheduler/compare/v1.0.1...v1.0.2
[1.0.1]: https://github.com/resque/resque-scheduler/compare/v1.0.0...v1.0.1
[1.0.0]: https://github.com/resque/resque-scheduler/compare/v0.0.1...v1.0.0
