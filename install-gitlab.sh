#!/bin/bash -e
# Author: Tuomo Tanskanen <tuomo@tanskanen.org>

# Gitlab version to install
DEB="gitlab_7.5.1-omnibus.5.2.0.ci-1_amd64.deb"
DEB_URL="https://downloads-packages.s3.amazonaws.com/ubuntu-12.04"
GITLAB_HOSTNAME="gitlab.invalid"

#
# Put your gitlab.rb config seed here
#
# Not all settings are presented here, but some subset
# Read the official documentation for adding more
# If you remove the config line, it will use the Gitlab default value
#
read -d '' CONFIG <<"EOF" || true
# Change the external_url to the address your users will type in their browser
# if http
# external_url 'http://gitlab.invalid/'

# if https
external_url 'https://gitlab.invalid/'
nginx['redirect_http_to_https'] = true
nginx['ssl_certificate'] = "/etc/ssl/certs/ssl-cert-snakeoil.pem"
nginx['ssl_certificate_key'] = "/etc/ssl/private/ssl-cert-snakeoil.key"

# These settings are documented in more detail at
# https://gitlab.com/gitlab-org/gitlab-ce/blob/master/config/gitlab.yml.example#L118

gitlab_rails['ldap_enabled'] = false
gitlab_rails['ldap_host'] = 'ldap.invalid'
gitlab_rails['ldap_port'] = 636
gitlab_rails['ldap_uid'] = 'uid'
gitlab_rails['ldap_method'] = 'ssl'
gitlab_rails['ldap_bind_dn'] = 'bind_user'
gitlab_rails['ldap_password'] = 'user_password'
gitlab_rails['ldap_allow_username_or_email_login'] = true
gitlab_rails['ldap_base'] = 'ldap_base'

# might want to disable this if ldap enabled
gitlab_rails['gitlab_signup_enabled'] = true
gitlab_rails['gitlab_signin_enabled'] = true

# limit the projects
gitlab_rails['gitlab_default_projects_limit'] = 100

# keep backup for about 4 weeks
gitlab_rails['backup_keep_time'] = 2404800

# unicorn conf
unicorn['worker_processes'] = 4
unicorn['worker_timeout'] = 180

# runit logs
logging['svlogd_size'] = 100 * 1024 * 1024 # rotate after 200 MB of log data
logging['svlogd_num'] = 30 # keep 30 rotated log files
logging['svlogd_timeout'] = 24 * 60 * 60 # rotate after 24 hours
logging['svlogd_filter'] = "gzip" # compress logs with gzip
logging['svlogd_udp'] = nil # transmit log messages via UDP
logging['svlogd_prefix'] = nil # custom prefix for log messages
EOF



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

# download omnibus-gitlab package (200M) and cache it
echo "Downloading Gitlab package from $DOWNLOAD ..."
(mkdir -p $CACHE && cd $CACHE && wget -nc -q $DOWNLOAD)

# install tools to automate this install
apt-get -y update
apt-get -y install debconf-utils

# install the few dependencies we have
echo "postfix postfix/main_mailer_type select Internet Site" | debconf-set-selections
echo "postfix postfix/mailname string $GITLAB_HOSTNAME" | debconf-set-selections
apt-get -y install openssh-server postfix
dpkg -i $CACHE/$DEB

# generate ssl keys
apt-get -y install ssl-cert
make-ssl-cert generate-default-snakeoil --force-overwrite

# fix the config and reconfigure
echo "${CONFIG}" >/etc/gitlab/gitlab.rb
gitlab-ctl reconfigure

# done
echo "Done!"
echo " Login at your host:port with 'root' + '5iveL!fe'"
echo " Config found at /etc/gitlab/gitlab.rb and updated by 'gitlab-ctl reconfigure'"
