#!/bin/bash -e
# Copyright 2013-2014 Tuomo Tanskanen <tuomo@tanskanen.org>

# Gitlab version to install
DEB="gitlab_7.5.3-omnibus.5.2.1.ci-1_amd64.deb"
DEB_MD5="96f087fb1960c89775c33f310aa3fffd"
DEB_URL="https://downloads-packages.s3.amazonaws.com/ubuntu-14.04"

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

# All commands expect root access.
[ "$(whoami)" != "root" ] && echo "error: need to be root" && exit 1

# install tools to automate this install
apt-get -y update
apt-get -y install debconf-utils

# download omnibus-gitlab package (250M) and cache it
echo "Downloading Gitlab package. This may take a while ..."
{
mkdir -p "$CACHE" && cd "$CACHE"
if [[ -e "$DEB" ]] && [[ $(md5sum $DEB | cut -f1 -d " ") = $DEB_MD5 ]]; then
  echo "Package found in cache."
else
  echo "Package does not match hash, re-downloading."
  rm "$DEB"
  echo "executing: wget -nc -q $DOWNLOAD"
fi
wget -nc -q $DOWNLOAD
if [[ $(md5sum $DEB | cut -f1 -d " ") != $DEB_MD5 ]]; then
  echo "error: Package does still not match hash!"
  exit 1
fi
}

# install the few dependencies we have
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string $GITLAB_HOSTNAME" | debconf-set-selections
apt-get -y install openssh-server postfix
dpkg -i $CACHE/$DEB

# generate ssl keys
apt-get -y install ssl-cert
make-ssl-cert generate-default-snakeoil --force-overwrite

# fix the config and reconfigure
cp /vagrant/gitlab.rb /etc/gitlab/gitlab.rb
gitlab-ctl reconfigure

# done
echo "Done!"
echo " Login at your host:port with 'root' + '5iveL!fe'"
echo " Config found at /etc/gitlab/gitlab.rb and updated by 'gitlab-ctl reconfigure'"
