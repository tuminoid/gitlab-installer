#!/bin/bash -e

# -----------------------------------------
# Mandatory settings here, please customize
# -----------------------------------------


# MySQL root password (will be used, not written)
MYSQL_ROOT_PASSWORD="mysqlpass"

# Gitlab user MySQL password
MYSQL_GITLAB_PASSWORD="gitlabpass"

# Gitlab email address
GITLAB_SERVER="127.0.0.1"
GITLAB_EMAIL="no-reply@gitlab.invalid"
GITLAB_SUPPORT_EMAIL="support@gitlab.invalid"

# Server FQDN
SERVER_NGINX_FQDN="127.0.0.1"
SERVER_NGINX_NAME="gitlab6"


# ---------------------------------------------
# Below this point it is optional congifuration
# Defaults work just fine
# ---------------------------------------------

# Postfix hostname
POSTFIX_HOSTNAME="precise64"

# Worker processes
WORKER_PROCESSES=4




#
#  --------------------------------
#  Installation - no need to touch!
#  --------------------------------
#


# All commands expect root access.
[ "$(whoami)" != "root" ] && echo "error: need to be root" && exit 1

# some helper exports
GITLAB_USER="git"
GITSUDO="sudo -u $GITLAB_USER -H"
GITHOME="/home/$GITLAB_USER"

# make sure we have sudo and editor, python-software-properties for apt-add-repository
export DEBIAN_FRONTEND=noninteractive
apt-get -y update
apt-get -y install sudo nano debconf-utils python-software-properties

# we need newer git than 1.7.9.5 in 12.04.2 LTS, so git-core ppa needs to be added
apt-add-repository -y ppa:git-core/ppa
# we also need ruby 2.0
add-apt-repository -y ppa:brightbox/ruby-ng-experimental

# update and upgrade
apt-get -y update
apt-get -y upgrade

# install dependencies
apt-get install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev \
  libncurses5-dev libffi-dev curl git-core openssh-server redis-server checkinstall libxml2-dev \
  libxslt-dev libcurl4-openssl-dev libicu-dev logrotate ruby2.0 ruby2.0-dev ruby2.0-doc

# install and verify python and postfix
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string $POSTFIX_HOSTNAME" | debconf-set-selections
apt-get install -y python python2.7 python-docutils postfix
python --version 2>&1 | grep -q "2."
which python2 || ln -sf /usr/bin/python /usr/bin/python2
sed -i 's,inet_interfaces = all,inet_interfaces = 127.0.0.1,' /etc/postfix/main.cf
service postfix restart

# HACK: try three times, ssl has issues from time to time
gem install bundler --no-ri --no-rdoc || gem install bundler --no-ri --no-rdoc || gem install bundler --no-ri --no-rdoc

# install system user
adduser --disabled-login --gecos 'GitLab' $GITLAB_USER

# install gitlab shell
cd $GITHOME
$GITSUDO git clone https://github.com/gitlabhq/gitlab-shell.git
cd gitlab-shell
$GITSUDO git checkout v1.7.1
$GITSUDO cp config.yml.example config.yml
$GITSUDO sed -i "s,gitlab_url: \"http://localhost/\",gitlab_url: \"http://$GITLAB_SERVER/\"," config.yml
$GITSUDO sed -i "s,\"/home/git/,\"$GITHOME/,g" config.yml
$GITSUDO sed -i "s,user: git,user: $GITLAB_USER," config.yml
$GITSUDO ./bin/install

# install mysql
echo "mysql-server-5.5 mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
apt-get install -y mysql-server mysql-client libmysqlclient-dev

cat <<EOF | mysql -u root --password=$MYSQL_ROOT_PASSWORD
CREATE USER 'gitlab'@'localhost' IDENTIFIED BY '$MYSQL_GITLAB_PASSWORD';
CREATE DATABASE IF NOT EXISTS \`gitlabhq_production\` DEFAULT CHARACTER SET \`utf8\` COLLATE \`utf8_unicode_ci\`;
GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON \`gitlabhq_production\`.* TO 'gitlab'@'localhost';
FLUSH PRIVILEGES;
EOF

# install gitlab
cd $GITHOME
$GITSUDO git clone https://github.com/gitlabhq/gitlabhq.git gitlab
cd $GITHOME/gitlab
$GITSUDO git checkout v6.2.0
$GITSUDO cp config/gitlab.yml.example config/gitlab.yml
$GITSUDO sed -i "s,host: localhost,host: $GITLAB_SERVER," config/gitlab.yml
$GITSUDO sed -i "s,email_from: gitlab@localhost,email_from: $GITLAB_EMAIL," config/gitlab.yml
$GITSUDO sed -i "s,support_email: gitlab@localhost,support_email: $GITLAB_SUPPORT_EMAIL," config/gitlab.yml
$GITSUDO sed -i "s,# user: git,user: $GITLAB_USER," config/gitlab.yml

chown -R $GITLAB_USER log/
chown -R $GITLAB_USER tmp/
chmod -R u+rwX  log/
chmod -R u+rwX  tmp/

$GITSUDO mkdir $GITHOME/gitlab-satellites
$GITSUDO mkdir tmp/pids/
$GITSUDO mkdir tmp/sockets/
chmod -R u+rwX  tmp/pids/
chmod -R u+rwX  tmp/sockets/

$GITSUDO mkdir public/uploads
chmod -R u+rwX  public/uploads

$GITSUDO cp config/unicorn.rb.example config/unicorn.rb
$GITSUDO sed -i "s,worker_processes 2,worker_processes $WORKER_PROCESSES," config/unicorn.rb

$GITSUDO git config --global user.name "GitLab"
$GITSUDO git config --global user.email "$GITLAB_EMAIL"
$GITSUDO git config --global core.autocrlf input

# configure gitlab db
$GITSUDO cp config/database.yml.mysql config/database.yml
$GITSUDO sed -i "s,username: root,username: gitlab," config/database.yml
$GITSUDO sed -i "s,password: \"secure password\",password: \"$MYSQL_GITLAB_PASSWORD\"," config/database.yml
$GITSUDO chmod o-rwx config/database.yml

# enable rack attack
$GITSUDO cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb
sed -i 's,# config.middleware.use Rack::Attack,config.middleware.use Rack::Attack,' config/application.rb

# install more gems
cd /home/$GITLAB_USER/gitlab
gem install charlock_holmes --version '0.6.9.4'
# HACK: try three times, there is sometimes issues with ssl with bundler 
$GITSUDO bundle install --deployment --without development test postgres aws || $GITSUDO bundle install --deployment --without development test postgres aws || $GITSUDO bundle install --deployment --without development test postgres aws

# initialize database and advanced features
echo "yes" | $GITSUDO bundle exec rake gitlab:setup RAILS_ENV=production

# install init script to start gitlab at boot
cp lib/support/init.d/gitlab /etc/init.d/gitlab
chmod +x /etc/init.d/gitlab
update-rc.d gitlab defaults 21

# setup logrotate
cp lib/support/logrotate/gitlab /etc/logrotate.d/gitlab

# install nginx
apt-get install -y nginx
cp lib/support/nginx/gitlab /etc/nginx/sites-available/$SERVER_NGINX_NAME
sed -i "s,server_name YOUR_SERVER_FQDN;,server_name $SERVER_NGINX_FQDN;," /etc/nginx/sites-available/$SERVER_NGINX_NAME
ln -s /etc/nginx/sites-available/$SERVER_NGINX_NAME /etc/nginx/sites-enabled/$SERVER_NGINX_NAME
rm -f /etc/nginx/sites-enabled/default
service nginx restart

# check installation and run services
$GITSUDO bundle exec rake gitlab:env:info RAILS_ENV=production
service gitlab start
$GITSUDO bundle exec rake gitlab:check RAILS_ENV=production

