require 'rubygems'
require 'test/unit'
require 'mocha'
$LOAD_PATH.unshift File.dirname(File.expand_path(__FILE__)) + '/../lib'
require 'resque_scheduler'

class SomeJob
  def self.perform(repo_id, path)
  end
end

class SomeIvarJob < SomeJob
  @queue = :ivar
end