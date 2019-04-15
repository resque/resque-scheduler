# vim:fileencoding=utf-8
source 'https://rubygems.org'

case req = ENV['RESQUE']
when nil
when 'master'
  gem 'resque', git: 'https://github.com/resque/resque'
else
  gem 'resque', req
end

gemspec
