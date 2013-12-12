class User < ActiveRecord::Base
  after_create :schedule_send_email
  
  private
  
  def schedule_send_email
    name = "send_email_#{self.id}"
    config = {}
    config[:class] = 'SendEmailJob'
    config[:args] = self.id
    config[:every] = '1d'
    Resque.set_schedule name, config
  end
end