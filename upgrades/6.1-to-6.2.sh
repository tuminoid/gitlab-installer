#!/bin/sh -e

# scripted installation of 6.1 to 6.2 upgrade
# https://github.com/gitlabhq/gitlabhq/blob/master/doc/update/6.1-to-6.2.md

# some options
GITUSER=git
GITHOME="/home/$GITUSER"
GITSUDO="sudo -u $GITUSER -H"

# All commands expect root access.
[ "$(whoami)" != "root" ] && echo "error: need to be root" && exit 1

# take backup
cd $GITHOME/gitlab
$GITSUDO bundle exec rake gitlab:backup:create RAILS_ENV=production
service gitlab stop

# checkout 6.2 close
$GITSUDO git fetch
$GITSUDO git checkout 6-2-stable

# install logrotate
apt-get install logrotate
cp lib/support/logrotate/gitlab /etc/logrotate.d/gitlab

# install libs and migrations
$GITSUDO bundle install --without development test postgres --deployment
$GITSUDO bundle exec rake db:migrate RAILS_ENV=production
$GITSUDO bundle exec rake assets:clean RAILS_ENV=production
$GITSUDO bundle exec rake assets:precompile RAILS_ENV=production
$GITSUDO bundle exec rake cache:clear RAILS_ENV=production

# setup config files
cd $GITHOME/gitlab/config
git diff 6-1-stable:config/gitlab.yml.example 6-2-stable:config/gitlab.yml.example > gitlab-61-to-62.patch
sed -i 's,/6-1-stable:config/gitlab.yml.example,/6-1-stable:config/gitlab.yml,' gitlab-61-to-62.patch
sed -i 's,/6-2-stable:config/gitlab.yml.example,/6-2-stable:config/gitlab.yml,' gitlab-61-to-62.patch
patch -p2 < gitlab-61-to-62.patch && rm gitlab-61-to-62.patch

git diff 6-1-stable:config/unicorn.rb.example 6-2-stable:config/unicorn.rb.example > unicorn-61-to-62.patch
sed -i 's,/6-1-stable:config/unicorn.rb.example,/6-1-stable:config/unicorn.rb,' unicorn-61-to-62.patch
sed -i 's,/6-2-stable:config/unicorn.rb.example,/6-2-stable:config/unicorn.rb,' unicorn-61-to-62.patch
patch -p2 < unicorn-61-to-62.patch && rm unicorn-61-to-62.patch

cd $GITHOME/gitlab
$GITSUDO cp config/initializers/rack_attack.rb.example config/initializers/rack_attack.rb
sed -i 's,# config.middleware.use Rack::Attack,config.middleware.use Rack::Attack,' config/application.rb

# update init script
rm /etc/init.d/gitlab
curl --output /etc/init.d/gitlab https://raw.github.com/gitlabhq/gitlabhq/6-2-stable/lib/support/init.d/gitlab
chmod +x /etc/init.d/gitlab

# restart services
service gitlab start
service nginx restart

# check health
$GITSUDO bundle exec rake gitlab:env:info RAILS_ENV=production
$GITSUDO bundle exec rake gitlab:check RAILS_ENV=production

# victory!
echo "VICTORY! Running 6.2!"
