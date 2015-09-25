gitlab-installer
================

Easy Gitlab installer, targeting Ubuntu 14.04 LTS, on Vagrant or on metal.

Usage
=====

Copy `gitlab.rb.example` to `gitlab.rb` and modify it with your preferences.
For complete template, please see https://gitlab.com/gitlab-org/omnibus-gitlab/blob/master/files/gitlab-config-template/gitlab.rb.template

In VM, Gitlab is available at https://127.0.0.1:8443/
In server install, Gitlab is available at https://127.0.0.1/

CI is integrated into Gitlab from version 8 onwards. 


Releases
========

Check tags for releases matching GitLab releases.

From Gitlab version 7.1.1 onwards, it utilizes the omnibus package instead of executing
long setup scripts. If you wish to use setup scripts or Puppet/Chef, there are plenty of
other choises.

From Gitlab version 7.11.2 onwards, it uses packageserver with apt. Which means there is
little reason to change the installer anymore.


Gitlab CI
=========

Gitlab CI and Gitlab CI Runner scripts were split into separate repository. You can find them at:
https://github.com/tuminoid/gitlabci-installer

From 7.5.1 onwards, CI is also enabled in this repository as it is bundled with Gitlab.
To disable CI, comment out `ci_external_url` line in script.

From 8 onwards, CI is part of Gitlab. You need to comment out following lines in `gitlab.rb`
(if you reuse your old `gitlab.rb`):
```
# ci_external_url 'http://gitlabci.invalid/'
# nginx['redirect_http_to_https'] = false
```

