#!/usr/bin/env bash
# Copyright (c) 2013-2016 Tuomo Tanskanen <tuomo@tanskanen.org>

# Usage: Copy 'gitlab.rb.example' as 'gitlab.rb', then 'vagrant up'.

set -e

# Gitlab flavor to install
GITLAB_FLAVOR="gitlab-ce"

# This is for postfix
GITLAB_HOSTNAME="gitlab.local"



#
#  --------------------------------
#  Installation - no need to touch!
#  --------------------------------
#

export DEBIAN_FRONTEND=noninteractive

fatal()
{
    echo "fatal: $@" >&2
}

check_for_root()
{
    if [[ $EUID != 0 ]]; then
        fatal "need to be root"
        exit 1
    fi
}

check_for_gitlab_rb()
{
    if [[ ! -e /vagrant/gitlab.rb ]]; then
        fatal "gitlab.rb not found at /vagrant"
        exit 1
    fi
}

check_for_backwards_compatibility()
{
    if egrep -q "^ci_external_url" /vagrant/gitlab.rb; then
        fatal "ci_external_url setting detected in 'gitlab.rb'"
        fatal "This setting is deprecated in Gitlab 8.0+, and will cause Chef to fail."
        fatal "Check the 'gitlab.rb.example' for fresh set of settings."
        exit 1
    fi
}

set_apt_pdiff_off()
{
    echo 'Acquire::PDiffs "false";' > /etc/apt/apt.conf.d/85pdiff-off
}


# All commands expect root access.
check_for_root

# Check for configs that are not compatible anymore
check_for_gitlab_rb
check_for_backwards_compatibility

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
set_apt_pdiff_off
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
