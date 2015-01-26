module ResqueWeb
  module Plugins
    module ResqueScheduler
      module DelayedHelper
        def format_time(t)
          t.strftime('%Y-%m-%d %H:%M:%S %z')
        end
      end
    end
  end
end
