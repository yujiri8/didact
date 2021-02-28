# Contains functions to send emails and generate email content from templates.
module Emails
  extend self

  # Warning: passing multiple recipient addresses will put them all in the To header,
  # revealing their addresses to each other. Call this multiple times for emailing
  # multiple users.
  def send(from, from_name, to : Array(String), subject, msg, wait = false)
    sendmail = Process.new("sendmail", ["-f", from, "-F", from_name] + to,
      # sendmail doesn't have a subject parameter, so we send it in through stdin.
      input: IO::Memory.new("Subject: #{subject}\n\n" + msg), error: Process::Redirect::Inherit)
    if wait
      status = sendmail.wait
      raise "Failed to send mail: #{status.inspect}" if !status.success?
    else
      # If we couldn't send the email and we aren't allowed to wait, at least log something.
      spawn do
        status = sendmail.wait
        puts "sendmail failed: #{status.inspect}" if !status.success?
      end
    end
  end

  # Generates a confirmation email.
  def confirm(email, token)
    ECR.render "email-templates/confirm.ecr"
  end

  # Generates a reply notification email.
  def reply_notif(comment)
    ECR.render "email-templates/reply.ecr"
  end

  # Generates an error notification email for the admin.
  def err_notif(env, exc)
    ECR.render "email-templates/err.ecr"
  end
end
