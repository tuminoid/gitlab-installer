#!/usr/bin/env bash
# Copyright (c) 2013-2016 Tuomo Tanskanen <tuomo@tanskanen.org>

# Usage: Copy 'gitlab.rb.example' as 'gitlab.rb', then 'vagrant up'.

set -e

# these are normally passed via Vagrantfile to environment
# but if you run this on bare metal they need to be reset
GITLAB_HOSTNAME=${GITLAB_HOSTNAME:-127.0.0.1}
GITLAB_PORT=${GITLAB_PORT:-8443}


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

install_swap_file()
{
    # "GITLAB_SWAP" is passed in environment by shell provisioner
    if [[ $GITLAB_SWAP > 0 ]]; then
        echo "Creating swap file of ${GITLAB_SWAP}G size"
        SWAP_FILE=/.swap.file
        dd if=/dev/zero of=$SWAP_FILE bs=1G count=$GITLAB_SWAP
        mkswap $SWAP_FILE
        echo "$SWAP_FILE none swap sw 0 0" >> /etc/fstab
        chmod 600 $SWAP_FILE
        swapon -a
    else
        echo "Skipped swap file creation due 'GITLAB_SWAP' set to 0"
    fi
}

rewrite_hostname()
{
    sed -i -e "s,^external_url.*,external_url 'https://${GITLAB_HOSTNAME}/'," /etc/gitlab/gitlab.rb
}


# All commands expect root access.
check_for_root

# Check for configs that are not compatible anymore
check_for_gitlab_rb
check_for_backwards_compatibility

# install swap file for more memory
install_swap_file

# install tools to automate this install
apt-get -y update
apt-get -y install debconf-utils curl

# install the few dependencies we have
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string $GITLAB_HOSTNAME" | debconf-set-selections
apt-get -y install openssh-server postfix

# generate ssl keys
apt-get -y install ca-certificates ssl-cert
make-ssl-cert generate-default-snakeoil --force-overwrite

# download omnibus-gitlab package (300M) with apt
# vagrant-cachier plugin hightly recommended
echo "Setting up Gitlab deb repository ..."
set_apt_pdiff_off
curl https://packages.gitlab.com/install/repositories/gitlab/gitlab-ce/script.deb.sh | sudo bash
echo "Installing gitlab-ce via apt ..."
apt-get install -y gitlab-ce

# fix the config and reconfigure
cp /vagrant/gitlab.rb /etc/gitlab/gitlab.rb
rewrite_hostname
gitlab-ctl reconfigure

# done
echo "Done!"
echo " Login at https://${GITLAB_HOSTNAME}:${GITLAB_PORT}/, username 'root'. Password will be reset on first login."
echo " Config found at /etc/gitlab/gitlab.rb and updated by 'sudo gitlab-ctl reconfigure'"
