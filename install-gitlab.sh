#!/usr/bin/env bash
# Copyright 2013, 2014, 2015 Tuomo Tanskanen <tuomo@tanskanen.org>

set -e

# Gitlab flavor to install
GITLAB_FLAVOR="gitlab-ce"

# This is for postfix
GITLAB_HOSTNAME="gitlab.invalid"

#
# Use provided gitlab.rb.example as base
#
[ ! -e /vagrant/gitlab.rb ] && { echo "error: gitlab.rb missing"; exit 1; }


#
#  --------------------------------
#  Installation - no need to touch!
#  --------------------------------
#

export DEBIAN_FRONTEND=noninteractive
CACHE=/var/cache/generic
DOWNLOAD="$DEB_URL/$DEB"

check_for_root()
{
  [[ $EUID = 0 ]] || { echo "error: need to be root" && exit 1; }
}

# All commands expect root access.
check_for_root

# install tools to automate this install
apt-get -y update
apt-get -y install debconf-utils wget curl

# install the few dependencies we have
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string $GITLAB_HOSTNAME" | debconf-set-selections
apt-get -y install openssh-server postfix

# generate ssl keys
apt-get -y install ca-certificates ssl-cert
make-ssl-cert generate-default-snakeoil --force-overwrite

# download omnibus-gitlab package (250M) and cache it
echo "Setting up Gitlab deb repository ..."
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
echo "Installing $GITLAB_FLAVOR via apt ..."
apt-get install -y $GITLAB_FLAVOR

# fix the config and reconfigure
cp /vagrant/gitlab.rb /etc/gitlab/gitlab.rb
gitlab-ctl reconfigure

# done
echo "Done!"
echo " Login at your host:port with 'root' + '5iveL!fe'"
echo " Config found at /etc/gitlab/gitlab.rb and updated by 'sudo gitlab-ctl reconfigure'"
