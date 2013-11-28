#!/bin/bash -e

# -----------------------------------------
# Mandatory settings here, please customize
# -----------------------------------------


# MySQL root password (will be used, not written)
MYSQL_ROOT_PASSWORD="mysqlpass"

# Gitlab_CI user MySQL password
MYSQL_GITLABCI_PASSWORD="gitlabcipass"

# Gitlab address
GITLABCI_GITLAB_SERVER="http://127.0.0.1"

# email
GITLABCI_EMAIL="no-reply@gitlabci.invalid"

# Nginx server FQDN
SERVERCI_NGINX_FQDN="127.0.0.1"
SERVERCI_NGINX_NAME="gitlab_ci"

# Nginx server port
SERVERCI_NGINX_PORT="3000"
# If CI is on a stand-alone server, use this instead
# SERVERCI_NGINX_PORT="*:80 default_server"


# ---------------------------------------------
# Below this point it is optional congifuration
# Defaults work just fine
# ---------------------------------------------

# Rubygems server
RUBYGEMS_SOURCE="http://rubygems.org"





#
#  --------------------------------
#  Installation - no need to touch!
#  --------------------------------
#


# All commands expect root access.
[ "$(whoami)" != "root" ] && echo "error: need to be root" && exit 1

# some helper exports
GITLABCI_USER="gitlab_ci"
CISUDO="sudo -u $GITLABCI_USER -H"
CIHOME="/home/$GITLABCI_USER"

# make sure we have sudo and editor, python-software-properties for apt-add-repository
export DEBIAN_FRONTEND=noninteractive
apt-get -y update
apt-get -y install sudo nano debconf-utils python-software-properties

# we need newer git than 1.7.9.5 in 12.04.2 LTS, so git-core ppa needs to be added
apt-add-repository -y ppa:git-core/ppa
# we also need ruby 2.0
add-apt-repository -y ppa:brightbox/ruby-ng-experimental
# update
apt-get -y update

# install dependencies
apt-get -y install wget curl gcc checkinstall libxml2-dev libxslt-dev libcurl4-openssl-dev \
  libreadline6-dev libc6-dev libssl-dev libmysql++-dev make build-essential \
  zlib1g-dev openssh-server git-core libyaml-dev postfix libpq-dev libicu-dev \
  redis-server logrotate ruby2.0 ruby2.0-dev ruby2.0-doc

# HACK: try three times, ssl has issues from time to time
gem install bundler --no-ri --no-rdoc || gem install bundler --no-ri --no-rdoc || gem install bundler --no-ri --no-rdoc

# install system user
adduser --disabled-login --gecos 'GitLab CI' $GITLABCI_USER
cd $CIHOME
$CISUDO git config --global user.name "GitLab CI"
$CISUDO git config --global user.email $GITLABCI_EMAIL
$CISUDO git config --global core.autocrlf input

# install mysql
# it is no-op if it installed already, not changing the root pass
echo "mysql-server-5.5 mysql-server/root_password_again password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
echo "mysql-server-5.5 mysql-server/root_password password $MYSQL_ROOT_PASSWORD" | debconf-set-selections
apt-get install -y mysql-server mysql-client libmysqlclient-dev

cat <<EOF | mysql -u root --password=$MYSQL_ROOT_PASSWORD
CREATE USER 'gitlab_ci'@'localhost' IDENTIFIED BY '$MYSQL_GITLABCI_PASSWORD';
CREATE DATABASE IF NOT EXISTS \`gitlab_ci_production\` DEFAULT CHARACTER SET \`utf8\` COLLATE \`utf8_unicode_ci\`;
GRANT SELECT, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON \`gitlab_ci_production\`.* TO 'gitlab_ci'@'localhost';
FLUSH PRIVILEGES;
EOF

# install gitlab-ci
cd $CIHOME
$CISUDO git clone https://github.com/gitlabhq/gitlab-ci.git
cd gitlab-ci
$CISUDO git checkout v4.0.0

# configure ci
$CISUDO cp config/application.yml.example config/application.yml
$CISUDO sed -i "s,- 'https://dev.gitlab.org/',- '$GITLABCI_GITLAB_SERVER'," config/application.yml
$CISUDO sed -i '/staging.gitlab.org/d' config/application.yml

# configure puma
$CISUDO cp config/puma.rb.example config/puma.rb

# configure db
$CISUDO cp config/database.yml.mysql config/database.yml
$CISUDO sed -i "s,username: root,username: gitlab_ci," config/database.yml
$CISUDO sed -i "s,password: \"secure password\",password: \"$MYSQL_GITLABCI_PASSWORD\"," config/database.yml
$CISUDO chmod o-rwx config/database.yml

# setup some dirs
$CISUDO mkdir -p tmp/pids/ tmp/sockets/
chmod -R u+rwX  tmp/pids/
chmod -R u+rwX  tmp/sockets/

# install more gems
# there is issues with rubygems ssl certs, thus we change the source, see config in the beginning
cd $CIHOME/gitlab-ci
$CISUDO sed -i -e "s,source 'https://rubygems.org',source '$RUBYGEMS_SOURCE'," Gemfile
$CISUDO bundle install --deployment --without development test postgres
$CISUDO sed -i -e "s,source '$RUBYGEMS_SOURCE',source 'https://rubygems.org'," Gemfile

# initialize database and advanced features
$CISUDO bundle exec rake db:setup RAILS_ENV=production
$CISUDO bundle exec whenever -w RAILS_ENV=production

# install init script to start gitlab at boot
cp lib/support/init.d/gitlab_ci /etc/init.d/gitlab_ci
chmod +x /etc/init.d/gitlab_ci
update-rc.d gitlab_ci defaults 21

# install nginx
apt-get install -y nginx
cp lib/support/nginx/gitlab_ci /etc/nginx/sites-available/$SERVERCI_NGINX_NAME
sed -i "s,server_name ci.gitlab.org;,server_name $SERVERCI_NGINX_FQDN;," /etc/nginx/sites-available/$SERVERCI_NGINX_NAME
sed -i "s,listen 80 default_server;,listen $SERVERCI_NGINX_PORT;," /etc/nginx/sites-available/$SERVERCI_NGINX_NAME
ln -s /etc/nginx/sites-available/$SERVERCI_NGINX_NAME /etc/nginx/sites-enabled/$SERVERCI_NGINX_NAME
rm -f /etc/nginx/sites-enabled/default
service nginx restart

# run services
service gitlab_ci start

# done
echo "Victory! Running GitLab CI 4.0.0!"
