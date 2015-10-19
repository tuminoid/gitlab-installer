# -*- mode: ruby -*-
# vi: set ft=ruby :
# Copyright 2013, 2014, 2015 Tuomo Tanskanen <tuomo@tanskanen.org>

Vagrant.require_version ">= 1.5.0"

Vagrant.configure("2") do |config|

  config.vm.define :gitlab do |config|
    # Configure some hostname here
    config.vm.hostname = "gitlab.invalid"
    config.vm.box = "ubuntu/trusty64"
    config.vm.provision :shell, :path => "install-gitlab.sh"

    # On Linux, we cannot forward ports <1024
    # We need to use higher ports, and have port forward or nginx proxy
    # or access the site via hostname:<port>, in this case 127.0.0.1:8080
    # By default, Gitlab is at https + port 8443 and Gitlab CI at 8081
    # config.vm.network :forwarded_port, guest: 80, host: 8080
    config.vm.network :forwarded_port, guest: 443, host: 8443
    config.vm.network :forwarded_port, guest: 80, host: 8081
  end

  # GitLab recommended specs
  config.vm.provider "virtualbox" do |v, override|
    v.cpus = 2
    v.memory = 2048
  end

  config.vm.provider "vmware_fusion" do |v, override|
    v.vmx["memsize"] = "2048"
    v.vmx["numvcpus"] = "2"
    override.vm.box = "puppetlabs/ubuntu-14.04-64-puppet"
  end

  config.vm.provider "lxc" do |v, override|
    override.vm.box = "fgrehm/trusty64-lxc"
  end
end
