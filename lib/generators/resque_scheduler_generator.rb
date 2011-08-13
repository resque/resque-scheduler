class ResqueSchedulerGenerator < Rails::Generators::Base

  source_root File.expand_path("../templates", __FILE__)

  def create_resque_scheduler_file
    template 'resque-scheduler', 'script/resque-scheduler'
    chmod 'script/resque-scheduler', 0755
  end

end
