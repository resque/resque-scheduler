# vim:fileencoding=utf-8

class SendEmailJob < ActiveJob::Base
  queue_as :send_emails

  def perform(_user_id)
    # ... do whatever you have to do to send an email to the user
  end
end
