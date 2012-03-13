class MailOnRails < Thor
  
  require 'colorize'
  require 'mysql'
  include Thor::Actions
  
  desc "config", "asks a few questions and configures mail_on_rails"
  def config
    root_password = ask("What is the root password for mysql on this system?") unless root_password
    socket = ask("Where is the mysql socket file located? ( full path, ex. /var/run/mysqld/mysqld.sock )") unless socket
    db_username = ask("What should the name of the mail_on_rails mysql worker account be?") unless db_username
    db_password = ask("What should the password of the mail_on_rails mysql worker account be?") unless db_password
    hostname = ask("What is the hostname for this machine?") unless hostname
    domain = ask("What is the domain name for this machine? ( include format, ex. domain.com )") unless domain
    
    dependencies
    database(db_username, db_password, root_password, socket)
    user
    postfix(db_username, db_password, domain, hostname)
    ssl
    sasl(db_username, db_password)
    dovecot(db_username, db_password, domain)
    aliases(domain)
    migrate
    
  end
  
  # todo: add flag for other pkg managers (yum, src?, etc...)
  desc "dependencies", "installs all software needed for mail_on_rails, for now assumes apt-get as package manager"
  def dependencies
    run('apt-get install postfix postfix-mysql postfix-doc mysql-client mysql-server dovecot-common dovecot-imapd dovecot-pop3d postfix libsasl2-2 libsasl2-modules libsasl2-modules-sql sasl2-bin libpam-mysql openssl telnet mailutils')
  end
  
  desc "database", "sets up databases for mail_on_rails, and makes a new database.yml file"
  def database(db_username = nil, db_password = nil, root_password = nil, socket = nil)
    root_password = ask("What is the root password for mysql on this system?") unless root_password
    socket = ask("Where is the mysql socket file located? ( full path, ex. /var/run/mysqld/mysqld.sock )") unless socket
    db_username = ask("What should the name of the mail_on_rails mysql worker account be?") unless db_username
    db_password = ask("What should the password of the mail_on_rails mysql worker account be?") unless db_password
    
    sql = Mysql::new("localhost", "root", "#{root_password}")

    sql.query(" CREATE USER '#{db_username}'@'localhost' IDENTIFIED BY '#{db_password}' ")
    sql.query(" CREATE DATABASE mail_on_rails_development ")
    sql.query(" CREATE DATABASE mail_on_rails_test ")
    sql.query(" CREATE DATABASE mail_on_rails_production ")
    sql.query(" GRANT ALL ON mail_on_rails_development.* TO '#{db_username}'@'localhost' ")
    sql.query(" GRANT ALL ON mail_on_rails_test.* TO '#{db_username}'@'localhost' ")
    sql.query(" GRANT ALL ON mail_on_rails_production.* TO '#{db_username}'@'localhost' ")

    # set up config/database.yml
    create_file "./config/database.yml", "\ndevelopment:\n  adapter: mysql2\n  encoding: utf8\n  reconnect: false\n  database: mail_on_rails_development\n  pool: 5\n  username: #{db_username}\n  password: #{db_password}\n  socket: #{socket}\n  \ntest:\n  adapter: mysql2\n  encoding: utf8\n  reconnect: false\n  database: mail_on_rails_test\n  pool: 5\n  username: #{db_username}\n  password: #{db_password}\n  socket: #{socket}\n\nproduction:\n  adapter: mysql2\n  encoding: utf8\n  reconnect: false\n  database: mail_on_rails_production\n  pool: 5\n  username: #{db_username}\n  password: #{db_password}\n  socket: #{socket}\n"
    
  end
  
  desc "user", "sets up a user account to operate the mail functions and hold mailboxes"
  def user
    run('groupadd -g 5000 mail_on_rails')
    run('useradd -g mail_on_rails -u 5000 mail_on_rails -d /home/mail_on_rails -m')
  end
  
  desc "postfix", "configures postfix installation to work with mail_on_rails"
  def postfix(db_username = nil, db_password = nil, domain = nil, hostname = nil)
    hostname = ask("What is the hostname for this machine?") unless hostname
    domain = ask("What is the domain name for this machine? ( include format, ex. domain.com )") unless domain
    db_username = ask("What is the mail_on_rails database worker username?") unless db_username
    db_password = ask("What is the mail_on_rails database worker password?") unless db_password
    
    # set up postfix mysql queries
    create_file "/etc/postfix/mysql-virtual_domains.cf", "user = #{db_username}\npassword = #{db_password}\ndbname = mail_on_rails_production\nquery = SELECT domain AS virtual FROM domains WHERE domain='%s'\nhosts = 127.0.0.1"
    create_file "/etc/postfix/mysql-virtual_forwardings.cf", "user = #{db_username}\npassword = #{db_password}\ndbname = mail_on_rails_production\nquery = SELECT destination FROM forwardings WHERE source='%s'\nhosts = 127.0.0.1"
    create_file "/etc/postfix/mysql-virtual_mailboxes.cf", "user = #{db_username}\npassword = #{db_password}\ndbname = mail_on_rails_production\nquery = SELECT CONCAT(SUBSTRING_INDEX(email,'@',-1),'/',SUBSTRING_INDEX(email,'@',1),'/') FROM users WHERE email='%s'\nhosts = 127.0.0.1"
    create_file "/etc/postfix/mysql-virtual_email2email.cf", "user = #{db_username}\npassword = #{db_password}\ndbname = mail_on_rails_production\nquery = SELECT email FROM users WHERE email='%s'\nhosts = 127.0.0.1"
    chmod "/etc/postfix/mysql-virtual_domains.cf", 0640
    chmod "/etc/postfix/mysql-virtual_forwardings.cf", 0640
    chmod "/etc/postfix/mysql-virtual_mailboxes.cf", 0640
    chmod "/etc/postfix/mysql-virtual_email2email.cf", 0640
    run('chgrp postfix /etc/postfix/mysql-virtual_*.cf')
    
    run("postconf -e 'myhostname = #{hostname}.#{domain}'")
    run("postconf -e 'mydestination = #{hostname}.#{domain}, localhost, localhost.localdomain'")
    run("postconf -e 'mynetworks = 127.0.0.0/8'")
    run("postconf -e 'message_size_limit = 30720000'")
    run("postconf -e 'virtual_alias_domains ='")
    run("postconf -e 'virtual_alias_maps = proxy:mysql:/etc/postfix/mysql-virtual_forwardings.cf, mysql:/etc/postfix/mysql-virtual_email2email.cf'")
    run("postconf -e 'virtual_mailbox_domains = proxy:mysql:/etc/postfix/mysql-virtual_domains.cf'")
    run("postconf -e 'virtual_mailbox_maps = proxy:mysql:/etc/postfix/mysql-virtual_mailboxes.cf'")
    run("postconf -e 'virtual_mailbox_base = /home/mail_on_rails'")
    run("postconf -e 'virtual_uid_maps = static:5000'")
    run("postconf -e 'virtual_gid_maps = static:5000'")
    run("postconf -e 'smtpd_sasl_auth_enable = yes'")
    run("postconf -e 'broken_sasl_auth_clients = yes'")
    run("postconf -e 'smtpd_sasl_authenticated_header = yes'")
    run("postconf -e 'smtpd_recipient_restrictions = permit_mynetworks, permit_sasl_authenticated, reject_unauth_destination'")
    run("postconf -e 'smtpd_use_tls = yes'")
    run("postconf -e 'smtpd_tls_cert_file = /etc/postfix/smtpd.cert'")
    run("postconf -e 'smtpd_tls_key_file = /etc/postfix/smtpd.key'")
    run("postconf -e 'virtual_create_maildirsize = yes'")
    run("postconf -e 'virtual_maildir_extended = yes'")
    run("postconf -e 'proxy_read_maps = $local_recipient_maps $mydestination $virtual_alias_maps $virtual_alias_domains $virtual_mailbox_maps $virtual_mailbox_domains $relay_recipient_maps $relay_domains $canonical_maps $sender_canonical_maps $recipient_canonical_maps $relocated_maps $transport_maps $mynetworks $virtual_mailbox_limit_maps'")
    run("postconf -e virtual_transport=dovecot")
    run("postconf -e dovecot_destination_recipient_limit=1")
    
  end
  
  desc "ssl", "creates a new ssl certificate for postfix"
  def ssl
    run("openssl req -new -outform PEM -out /etc/postfix/smtpd.cert -newkey rsa:2048 -nodes -keyout /etc/postfix/smtpd.key -keyform PEM -days 365 -x509")
    run("chmod o= /etc/postfix/smtpd.key")
  end
  
  desc "sasl", "sets up the SASL Authentication Daemon"
  def sasl(db_username = nil, db_password = nil)
    db_username = ask("What is the mail_on_rails database worker username?") unless db_username
    db_password = ask("What is the mail_on_rails database worker password?") unless db_password
    empty_directory("/var/spool/postfix/var/run/saslauthd")
#    copy_file("/etc/default/saslauthd", "/etc/default/saslauthd.bak") if File.exists?("/etc/default/saslauthd")
    create_file "/etc/default/saslauthd", "START=yes\nDESC=\"SASL Authentication Daemon\"\nNAME=\"saslauthd\"\nMECHANISMS=\"pam\"\nMECH_OPTIONS=\"\"\nTHREADS=5\nOPTIONS=\"-c -m /var/spool/postfix/var/run/saslauthd -r\""
    create_file "/etc/pam.d/smtp", "auth    required   pam_mysql.so user=#{db_username} passwd=#{db_password} host=127.0.0.1 db=mail_on_rails_production table=users usercolumn=email passwdcolumn=password crypt=1\naccount sufficient pam_mysql.so user=#{db_username} passwd=#{db_password} host=127.0.0.1 db=mail_on_rails_production table=users usercolumn=email passwdcolumn=password crypt=1"
    create_file "/etc/postfix/sasl/smtpd.conf", "pwcheck_method: saslauthd\nmech_list: plain login\nallow_plaintext: true\nauxprop_plugin: mysql\nsql_hostnames: 127.0.0.1\nsql_user: #{db_username}\nsql_passwd: #{db_password}\nsql_database: mail_on_rails_production\nsql_select: select password from users where email = '%u'"
    run('chmod o= /etc/pam.d/smtp')
    run('chmod o= /etc/postfix/sasl/smtpd.conf')
    run('adduser postfix sasl')
    run('service postfix restart')
    run('service saslauthd restart')
  end
  
  desc "dovecot", "sets up dovecot to work with mail_on_rails"
  def dovecot(db_username = nil, db_password = nil, domain = nil)
    db_username = ask("What is the mail_on_rails database worker username?") unless db_username
    db_password = ask("What is the mail_on_rails database worker password?") unless db_password
    domain = ask("What is the domain name for this machine? ( include format, ex. domain.com )") unless domain
    append_file "/etc/postfix/master.cf", "dovecot   unix  -       n       n       -       -       pipe\n\tflags=DRhu user=mail_on_rails:mail_on_rails argv=/usr/lib/dovecot/deliver -d ${recipient}"
#    copy_file "/etc/dovecot/dovecot.conf", "/etc/dovecot/dovecot.conf.bak"
    create_file "/etc/dovecot/dovecot.conf", "protocols = imap imaps pop3 pop3s\nlog_timestamp = \"\%Y-\%m-\%d \%H:\%M:\%S \"\nmail_location = maildir:/home/mail_on_rails/\%d/\%n/Maildir\n\nssl_cert_file = /etc/ssl/certs/dovecot.pem\nssl_key_file = /etc/ssl/private/dovecot.pem\n\nnamespace private {\n    separator = .\n    prefix = INBOX.\n    inbox = yes\n}\n\nprotocol lda {\n    log_path = /home/mail_on_rails/dovecot-deliver.log\n    auth_socket_path = /var/run/dovecot/auth-master\n    postmaster_address = postmaster@#{domain}\n    mail_plugins = sieve\n    global_script_path = /home/mail_on_rails/globalsieverc\n}\n\nprotocol pop3 {\n    pop3_uidl_format = \%08Xu\%08Xv\n}\n\nauth default {\n    user = root\n\n    passdb sql {\n        args = /etc/dovecot/dovecot-sql.conf\n    }\n\n    userdb static {\n        args = uid=5000 gid=5000 home=/home/mail_on_rails/\%d/\%n allow_all_users=yes\n    }\n\n    socket listen {\n        master {\n            path = /var/run/dovecot/auth-master\n            mode = 0600\n            user = mail_on_rails\n        }\n\n        client {\n            path = /var/spool/postfix/private/auth\n            mode = 0660\n            user = postfix\n            group = postfix\n        }\n    }\n}"
#    copy_file "/etc/dovecot/dovecot-sql.conf", "/etc/dovecot/dovecot-sql.conf.bak"
    create_file "/etc/dovecot/dovecot-sql.conf", "driver = mysql\nconnect = host=127.0.0.1 dbname=mail_on_rails_production user=#{db_username} password=#{db_password}\ndefault_pass_scheme = CRYPT\npassword_query = SELECT email as user, password FROM users WHERE email='%u';"
    run('service dovecot restart')
    run('chgrp mail_on_rails /etc/dovecot/dovecot.conf')
    run('chmod g+r /etc/dovecot/dovecot.conf')
  end
  
  desc "aliases", "sets the proper root and postmaster aliases"
  def aliases(domain = nil)
    domain = ask("What is the domain name for this machine? ( include format, ex. domain.com )") unless domain
    append_file "/etc/aliases", "postmaster: root\nroot: postmaster@#{domain}"
    run('newaliases')
    run('service postfix restart')
  end
  
  desc "migrate", "migrates the development and production databases for mail_on_rails"
  def migrate
    run('rake db:migrate')
    run('rake db:migrate RAILS_ENV=production')
  end
  
end