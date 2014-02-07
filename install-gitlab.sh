#!/bin/bash -e

# -----------------------------------------
# Mandatory settings here, please customize
# -----------------------------------------

# Gitlab version to install
TARGET_VERSION="v6.5.1"

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
SERVER_NGINX_NAME="gitlab"


# ---------------------------------------------
# Below this point it is optional congifuration
# Defaults work just fine
# ---------------------------------------------

# Rubygems server
RUBYGEMS_SOURCE="http://rubygems.org"

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
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string $POSTFIX_HOSTNAME" | debconf-set-selections
apt-get install -y curl git-core openssh-server redis-server checkinstall logrotate postfix \
  build-essential libicu-dev libxml2-dev libxslt-dev \
  ruby2.0 ruby2.0-dev

# HACK: try three times, ssl has issues from time to time
for i in 1 2 3; do
  gem install bundler --no-ri --no-rdoc && break
done

# install system user
adduser --disabled-login --gecos 'GitLab' $GITLAB_USER
cd $GITHOME
$GITSUDO git config --global user.name "GitLab"
$GITSUDO git config --global user.email $GITLAB_EMAIL
$GITSUDO git config --global core.autocrlf input

# install gitlab shell
cd $GITHOME
$GITSUDO git clone https://github.com/gitlabhq/gitlab-shell.git
cd gitlab-shell
$GITSUDO git checkout v1.8.0
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
$GITSUDO git checkout $TARGET_VERSION
$GITSUDO cp config/gitlab.yml.example config/gitlab.yml
$GITSUDO sed -i "s,host: localhost,host: $GITLAB_SERVER," config/gitlab.yml
$GITSUDO sed -i "s,email_from: gitlab@localhost,email_from: $GITLAB_EMAIL," config/gitlab.yml
$GITSUDO sed -i "s,support_email: support@localhost,support_email: $GITLAB_SUPPORT_EMAIL," config/gitlab.yml
$GITSUDO sed -i "s,# user: git,user: $GITLAB_USER," config/gitlab.yml

chown -R $GITLAB_USER log/
chown -R $GITLAB_USER tmp/
chmod -R u+rwX  log/
chmod -R u+rwX  tmp/

$GITSUDO mkdir $GITHOME/gitlab-satellites
$GITSUDO mkdir -p tmp/pids/ tmp/sockets/
chmod -R u+rwX  tmp/pids/
chmod -R u+rwX  tmp/sockets/

$GITSUDO mkdir -p public/uploads
chmod -R u+rwX  public/uploads

$GITSUDO cp config/unicorn.rb.example config/unicorn.rb
$GITSUDO sed -i "s,worker_processes 2,worker_processes $WORKER_PROCESSES," config/unicorn.rb

# configure gitlab db
$GITSUDO cp config/database.yml.mysql config/database.yml
$GITSUDO sed -i "s,username: git,username: gitlab," config/database.yml
$GITSUDO sed -i "s,password: \"secure password\",password: \"$MYSQL_GITLAB_PASSWORD\"," config/database.yml
$GITSUDO chmod o-rwx config/database.yml

# enable rack attack
$GITSUDO cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb
sed -i 's,# config.middleware.use Rack::Attack,config.middleware.use Rack::Attack,' config/application.rb

# install more gems
# there is issues with rubygems ssl certs, thus we change the source, see config in the beginning
cd $GITHOME/gitlab
$GITSUDO sed -i -e "s,source \"https://rubygems.org\",source \"$RUBYGEMS_SOURCE\"," Gemfile
gem install charlock_holmes --version '0.6.9.4'
for i in 1 2 3; do
  $GITSUDO bundle install --deployment --without development test postgres aws && break
done
$GITSUDO sed -i -e "s,source \"$RUBYGEMS_SOURCE\",source \"https://rubygems.org\"," Gemfile

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
ln -sf /etc/nginx/sites-available/$SERVER_NGINX_NAME /etc/nginx/sites-enabled/$SERVER_NGINX_NAME
rm -f /etc/nginx/sites-enabled/default
service nginx restart

# check installation and run services
$GITSUDO bundle exec rake gitlab:env:info RAILS_ENV=production
service gitlab start
$GITSUDO bundle exec rake gitlab:check RAILS_ENV=production

# done
echo "Victory! Running GitLab $TARGET_VERSION!"
