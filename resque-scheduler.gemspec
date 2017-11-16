# vim:fileencoding=utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'resque/scheduler/version'

Gem::Specification.new do |spec|
  spec.name = 'resque-scheduler'
  spec.version = Resque::Scheduler::VERSION
  spec.authors = <<-EOF.split(/\n/).map(&:strip)
    Ben VandenBos
    Simon Eskildsen
    Ryan Biesemeyer
    Dan Buch
  EOF
  spec.email = %w(
    bvandenbos@gmail.com
    sirup@sirupsen.com
    ryan@yaauie.com
    dan@meatballhat.com
  )
  spec.summary = 'Light weight job scheduling on top of Resque'
  spec.description = <<-DESCRIPTION
    Light weight job scheduling on top of Resque.
    Adds methods enqueue_at/enqueue_in to schedule jobs in the future.
    Also supports queueing jobs on a fixed, cron-like schedule.
  DESCRIPTION
  spec.homepage = 'http://github.com/resque/resque-scheduler'
  spec.license = 'MIT'

  spec.files = `git ls-files -z`.split("\0").reject do |f|
    f.match(%r{^(test|spec|features|examples|bin|tasks)/}) ||
      f.match(/^(Vagrantfile|Gemfile\.lock|appveyor\.yml)/) ||
      f.match(/^\.(rubocop|simplecov|travis|vagrant|gitignore)/)
  end
  spec.bindir = 'exe'
  spec.executables = spec.files.grep(%r{^exe/}) { |f| File.basename(f) }
  spec.require_paths = %w(lib)

  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'json'
  spec.add_development_dependency 'kramdown'
  spec.add_development_dependency 'minitest'
  spec.add_development_dependency 'mocha'
  spec.add_development_dependency 'pry'
  spec.add_development_dependency 'rack-test'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'simplecov'
  spec.add_development_dependency 'test-unit'
  spec.add_development_dependency 'yard'
  spec.add_development_dependency 'tzinfo-data'

  # We pin rubocop because new cops have a tendency to result in false-y
  # positives for new contributors, which is not a nice experience.
  spec.add_development_dependency 'rubocop', '~> 0.40.0'

  spec.add_runtime_dependency 'mono_logger', '~> 1.0'
  spec.add_runtime_dependency 'redis', '>= 3.3', '< 5'
  spec.add_runtime_dependency 'resque', '~> 1.26'
  spec.add_runtime_dependency 'rufus-scheduler', '~> 3.2'
end
