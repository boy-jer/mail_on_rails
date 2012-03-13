class User < ActiveRecord::Base
  
  belongs_to :domain
  
  before_create :init_account
  
  def init_account
    pass = random_password
    set_password(pass)
    Notifier.welcome(self, pass).deliver
  end
  
  def random_password(size = 8)
    chars = (('a'..'z').to_a + ('0'..'9').to_a) - %w(i o 0 1 l 0)
    (1..size).collect{|a| chars[rand(chars.size)] }.join
  end
  
  def set_random_password
    pass = random_password
    set_password(pass)
    Notifier.random_reset(self, pass).deliver
  end
  
  def set_password(new_password)
    config = Rails.configuration.database_configuration
    db = Mysql2::Client.new(:host => 'localhost', :username => config[Rails.env]["username"].to_s, :password => config[Rails.env]["password"].to_s, :database => config[Rails.env]["database"].to_s)
    r = db.query("SELECT ENCRYPT('#{new_password}', '#{self.username}')")
    r.first.each_value do |x|
      if self.new_record?
        self.password = x
      else
        self.update_attributes(:password => x)
      end
    end
  end
  
  def check_password(password)
    config = Rails.configuration.database_configuration
    db = Mysql2::Client.new(:host => 'localhost', :username => config[Rails.env]["username"].to_s, :password => config[Rails.env]["password"].to_s, :database => config[Rails.env]["database"].to_s)
    r = db.query("SELECT ENCRYPT('#{password}', '#{self.username}')")
    r.first.each_value do |x|
      if self.password.to_s == x.to_s
        return true
      else
        return false
      end
    end
  end
  
end
