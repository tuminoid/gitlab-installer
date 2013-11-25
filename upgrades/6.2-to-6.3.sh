#!/bin/sh -e

# scripted installation of 6.2 to 6.3 upgrade
# https://github.com/gitlabhq/gitlabhq/blob/master/doc/update/6.2-to-6.3.md

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

# checkout 6.3
$GITSUDO git fetch
# config/application.rb is not .example based, thus we need to manually fiddle with the one line difference
#  (6.2 has changed rack attack line and the comment about it is extra)
$GITSUDO grep -v "    # Uncomment to enable rack attack middleware" config/application.rb > config/application.rb.new && $GITSUDO mv config/application.rb.new config/application.rb
$GITSUDO git stash
$GITSUDO git checkout v6.3.0
$GITSUDO git stash pop

# checkout shell 1.7.9
cd $GITHOME/gitlab-shell
$GITSUDO git fetch
$GITSUDO git checkout v1.7.9

# install libs and migrations
cd $GITHOME/gitlab
$GITSUDO bundle install --without development test postgres --deployment
$GITSUDO bundle exec rake db:migrate RAILS_ENV=production
$GITSUDO bundle exec rake assets:clean RAILS_ENV=production
$GITSUDO bundle exec rake assets:precompile RAILS_ENV=production
$GITSUDO bundle exec rake cache:clear RAILS_ENV=production

# setup config files - nothing really has changed
cd $GITHOME/gitlab/config
git diff v6.2.0:config/gitlab.yml.example v6.3.0:config/gitlab.yml.example > gitlab-62-to-63.patch
sed -i 's,/v6.2.0:config/gitlab.yml.example,/v6.2.0:config/gitlab.yml,' gitlab-62-to-63.patch
sed -i 's,/v6.3.0:config/gitlab.yml.example,/v6.3.0:config/gitlab.yml,' gitlab-62-to-63.patch
patch -p2 < gitlab-62-to-63.patch && rm gitlab-62-to-63.patch

# update init script
rm /etc/init.d/gitlab
curl --output /etc/init.d/gitlab https://raw.github.com/gitlabhq/gitlabhq/v6.3.0/lib/support/init.d/gitlab
chmod +x /etc/init.d/gitlab

# restart services
service gitlab start
service nginx restart

# check health
$GITSUDO bundle exec rake gitlab:env:info RAILS_ENV=production
$GITSUDO bundle exec rake gitlab:check RAILS_ENV=production

# victory!
echo "VICTORY! Running 6.3!"
