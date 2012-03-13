class Notifier < ActionMailer::Base
  
  default from: "mail@arosscohen.com"
  
  def welcome(user, temporary_password)
    @user = user
    @temporary_password = temporary_password
    mail(:to => @user.backup_email, :subject => "Welcome #{@user.email}, please set your password.")
  end
  
  def random_reset(user, temporary_password)
    @user = user
    @temporary_password = temporary_password
    mail(:to => @user.backup_email, :subject => "#{@user.email} Password Reset Request.")
  end
  
end
