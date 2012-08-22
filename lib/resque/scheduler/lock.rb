%w[base basic resilient].each do |file|
  require "resque/scheduler/lock/#{file}"
end
