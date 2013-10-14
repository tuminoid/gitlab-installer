#!/bin/bash

# dev stuff - FIXME
if [ -d "/vagrant/.cache/deb" ]; then
  mkdir -p /var/cache/apt/archives
  cp /vagrant/.cache/deb/*.deb /var/cache/apt/archives/
fi

# make sure we have sudo and editor
export DEBIAN_FRONTEND=noninteractive
apt-get -y update
apt-get -y install sudo nano debconf-utils python-software-properties

# we need newer git than 1.7.9.5 in 12.04.2 LTS, so git-core ppa needs to be added
apt-add-repository -y ppa:git-core/ppa
apt-get -y update
apt-get -y upgrade

# install dependencies
apt-get install -y build-essential zlib1g-dev libyaml-dev libssl-dev libgdbm-dev libreadline-dev \
  libncurses5-dev libffi-dev curl git-core openssh-server redis-server checkinstall libxml2-dev \
  libxslt-dev libcurl4-openssl-dev libicu-dev

# install and verify python and postfix
echo 'postfix postfix/main_mailer_type select Internet Site' | debconf-set-selections
echo 'postfix postfix/mailname string precise64' | debconf-set-selections
apt-get install -y python python2.7 python-docutils postfix
python --version | grep -q "2."
python2 --version || ln -s /usr/bin/python /usr/bin/python2

# remove old ruby and install new one
apt-get remove -y ruby1.8
mkdir /tmp/ruby && cd /tmp/ruby
curl --progress ftp://ftp.ruby-lang.org/pub/ruby/2.0/ruby-2.0.0-p247.tar.gz | tar xz
cd ruby-2.0.0-p247
./configure
make -j4
make install

# install gem bundler
gem install bundler --no-ri --no-rdoc

# install system user
adduser --disabled-login --gecos 'GitLab' git

# install gitlab shell
cd /home/git
sudo -u git -H git clone https://github.com/gitlabhq/gitlab-shell.git
cd gitlab-shell
sudo -u git -H git checkout v1.7.1
sudo -u git -H cp config.yml.example config.yml
sudo -u git -H ./bin/install

# install mysql
echo 'mysql-server-5.5 mysql-server/root_password_again password pass' | debconf-set-selections
echo 'mysql-server-5.5 mysql-server/root_password password pass' | debconf-set-selections
apt-get install -y mysql-server mysql-client libmysqlclient-dev

cat <<EOF | mysql -u root --password=pass
CREATE USER 'gitlab'@'localhost' IDENTIFIED BY 'pass';
CREATE DATABASE IF NOT EXISTS \`gitlabhq_production\` DEFAULT CHARACTER SET \`utf8\` COLLATE \`utf8_unicode_ci\`;
GRANT SELECT, LOCK TABLES, INSERT, UPDATE, DELETE, CREATE, DROP, INDEX, ALTER ON \`gitlabhq_production\`.* TO 'gitlab'@'localhost';
FLUSH PRIVILEGES;
EOF
sudo -u git -H mysql -u gitlab --password=pass -D gitlabhq_production

# install gitlab
cd /home/git
sudo -u git -H git clone https://github.com/gitlabhq/gitlabhq.git gitlab
cd /home/git/gitlab
sudo -u git -H git checkout 6-1-stable
sudo -u git -H cp config/gitlab.yml.example config/gitlab.yml
sudo -u git -H sed -i 's,host: localhost,host: 127.0.0.1,' config/gitlab.yml
sudo -u git -H sed -i 's,gitlab_url: "http://localhost/",gitlab_url: "http://127.0.0.1/",' config.yml
sudo -u git -H sed -i 's,email_from: gitlab@localhost,email_from: tumi+gitlab@tumi.fi,' config/gitlab.yml

chown -R git log/
chown -R git tmp/
chmod -R u+rwX  log/
chmod -R u+rwX  tmp/

sudo -u git -H mkdir /home/git/gitlab-satellites
sudo -u git -H mkdir tmp/pids/
sudo -u git -H mkdir tmp/sockets/
chmod -R u+rwX  tmp/pids/
chmod -R u+rwX  tmp/sockets/

sudo -u git -H mkdir public/uploads
chmod -R u+rwX  public/uploads

sudo -u git -H cp config/unicorn.rb.example config/unicorn.rb
sudo -u git -H sed -i 's,worker_processes 2,worker_processes 4,' config/unicorn.rb

sudo -u git -H git config --global user.name "GitLab"
sudo -u git -H git config --global user.email "tumi+gitlab@tumi.fi"
sudo -u git -H git config --global core.autocrlf input

# configure gitlab db
sudo -u git cp config/database.yml.mysql config/database.yml
sudo -u git -H sed -i 's,username: root,username: gitlab,' config/database.yml
sudo -u git -H sed -i 's,password: "secure password",password: "pass",' config/database.yml
sudo -u git -H chmod o-rwx config/database.yml

# install more gems
cd /home/git/gitlab
gem install charlock_holmes --version '0.6.9.4'
sudo -u git -H bundle install --deployment --without development test postgres aws

# initialize database and advanced features
echo "yes" | sudo -u git -H bundle exec rake gitlab:setup RAILS_ENV=production

# install init script to start gitlab at boot
cp lib/support/init.d/gitlab /etc/init.d/gitlab
chmod +x /etc/init.d/gitlab
update-rc.d gitlab defaults 21

# check installation
sudo -u git -H bundle exec rake gitlab:env:info RAILS_ENV=production
service gitlab start
sudo -u git -H bundle exec rake gitlab:check RAILS_ENV=production

# install nginx
apt-get install -y nginx
cp lib/support/nginx/gitlab /etc/nginx/sites-available/gitlab
ln -s /etc/nginx/sites-available/gitlab /etc/nginx/sites-enabled/gitlab
sudo -u git -H sed -i 's,server_name YOUR_SERVER_FQDN;,server_name 127.0.0.1;,' config/database.yml
service nginx restart

# save cache - FIXME
mkdir -p /vagrant/.cache/deb
cp /var/cache/apt/archives/*.deb /vagrant/.cache/deb/

