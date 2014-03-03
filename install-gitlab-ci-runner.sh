#!/bin/bash -e

# -----------------------------------------
# Mandatory settings here, please customize
# -----------------------------------------


# Token from CI UI (mandatory change or must come from cmdline)
REGISTRATION_TOKEN=${REGISTRATION_TOKEN:-""}

# GitLab CI address
CI_SERVER_URL=${CI_SERVER_URL:-"http://127.0.0.1:3000"}

# GitLab address (without protocol)
GITLAB_URL=${GITLAB_URL:-"127.0.0.1"}

# Make X runner dirs
CIR_COUNT=1

# Spawn X runners per account
CIR_SPAWN_COUNT=1


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
CIR_USER="gitlab_ci_runner"
CIRSUDO="sudo -u $CIR_USER -H"
CIRHOME="/home/$CIR_USER"

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
apt-get -y install wget curl gcc libxml2-dev libxslt-dev libcurl4-openssl-dev \
  libreadline6-dev libc6-dev libssl-dev make build-essential zlib1g-dev \
  openssh-server git-core libyaml-dev postfix libpq-dev libicu-dev \
  ruby2.0 ruby2.0-dev ruby2.0-doc
update-alternatives --set ruby /usr/bin/ruby2.0

# install system user
adduser --disabled-login --gecos 'GitLab CI Runner' $CIR_USER

# install gitlab-ci-runner
cd $CIRHOME
$CIRSUDO git clone https://github.com/gitlabhq/gitlab-ci-runner.git
cd gitlab-ci-runner

# setup some dirs
$CIRSUDO mkdir -p tmp/pids/ tmp/sockets/
chmod -R u+rwX  tmp/pids/
chmod -R u+rwX  tmp/sockets/

# install more gems
# there is issues with rubygems ssl certs, thus we change the source, see config in the beginning
cd $CIRHOME/gitlab-ci-runner
gem install bundler --no-ri --no-rdoc || gem install bundler --no-ri --no-rdoc || gem install bundler --no-ri --no-rdoc
$CIRSUDO sed -i -e "s,source 'https://rubygems.org',source '$RUBYGEMS_SOURCE'," Gemfile
bundle install
$CIRSUDO sed -i -e "s,source '$RUBYGEMS_SOURCE',source 'https://rubygems.org'," Gemfile

if [ ! -z "$REGISTRATION_TOKEN" ]; then
  $CIRSUDO REGISTRATION_TOKEN=$REGISTRATION_TOKEN CI_SERVER_URL=$CI_SERVER_URL\
    bundle exec ./bin/setup
  ssh-keyscan -H $GITLAB_URL >> $CIRHOME/.ssh/known_hosts

  # install init script to start gitlab at boot
  cp lib/support/init.d/gitlab_ci_runner /etc/init.d/gitlab_ci_runner
  chmod +x /etc/init.d/gitlab_ci_runner
  sed -i "s,RUNNERS_NUM=1,RUNNERS_NUM=$CIR_SPAWN_COUNT," /etc/init.d/gitlab_ci_runner
  update-rc.d gitlab_ci_runner defaults 21

  # run services
  service gitlab_ci_runner start

  # done
  echo "Victory! Running GitLab CI Runner with $CIR_COUNT workers!"
else
  echo "Final setup with REGISTRATION_TOKEN required. Dependencies installed!"
fi
