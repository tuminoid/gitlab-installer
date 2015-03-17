#!/usr/bin/env bash
# Copyright 2013-2014 Tuomo Tanskanen <tuomo@tanskanen.org>

set -e

# Gitlab version to install
DEB="gitlab_7.8.4-omnibus-1_amd64.deb"
DEB_MD5="b82abff9751a5375588a00f579aff8f9"
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

check_for_root()
{
  [[ $EUID = 0 ]] || { echo "error: need to be root" && exit 1; }
}

download_package()
{
  mkdir -p "$CACHE" && cd "$CACHE"
  if [[ -e "$DEB" ]] && [[ $(md5sum "$DEB" | cut -f1 -d " ") = $DEB_MD5 ]]; then
    echo "Package has been downloaded previously, using cached binary."
  else
    [[ -e "$DEB" ]] && rm -f "$DEB" && echo "Package hash does not match, re-downloading."
    echo "Executing: wget -nc -q $DOWNLOAD"
  fi

  wget -nc -q $DOWNLOAD
  if [[ $(md5sum $DEB | cut -f1 -d " ") != $DEB_MD5 ]]; then
    echo "error: Package hash is still not valid, exiting ..."
    exit 1
  fi
}

# All commands expect root access.
check_for_root

# install tools to automate this install
apt-get -y update
apt-get -y install debconf-utils wget

# install the few dependencies we have
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string $GITLAB_HOSTNAME" | debconf-set-selections
apt-get -y install openssh-server postfix

# generate ssl keys
apt-get -y install ssl-cert
make-ssl-cert generate-default-snakeoil --force-overwrite

# download omnibus-gitlab package (250M) and cache it
echo "Downloading Gitlab package. This may take a while ..."
download_package
dpkg -i $CACHE/$DEB

# fix the config and reconfigure
cp /vagrant/gitlab.rb /etc/gitlab/gitlab.rb
gitlab-ctl reconfigure

# done
echo "Done!"
echo " Login at your host:port with 'root' + '5iveL!fe'"
echo " Config found at /etc/gitlab/gitlab.rb and updated by 'sudo gitlab-ctl reconfigure'"
