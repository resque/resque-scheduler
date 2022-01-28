# vim:fileencoding=utf-8
%w(base basic resilient resilient_modern).each do |file|
  require "resque/scheduler/lock/#{file}"
end
