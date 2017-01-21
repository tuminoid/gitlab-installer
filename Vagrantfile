# -*- mode: ruby -*-
# vi: set ft=ruby :
# Copyright (c) 2013-2016 Tuomo Tanskanen <tuomo@tanskanen.org>

# read configurable cpu/memory/port/swap/flavor settings from environment variables
memory = ENV['GITLAB_MEMORY'] || 2048
cpus = ENV['GITLAB_CPUS'] || 1
port = ENV['GITLAB_PORT'] || 8443
swap = ENV['GITLAB_SWAP'] || 0
host = ENV['GITLAB_HOST'] || "gitlab.local"

Vagrant.require_version ">= 1.5.0"

Vagrant.configure("2") do |config|

  config.vm.define :gitlab do |config|
    # Configure some hostname here
    config.vm.hostname = host
    config.vm.box = "ubuntu/xenial64"
    config.vm.provision :shell, :path => "install-gitlab.sh",
      env: { "GITLAB_SWAP" => swap, "GITLAB_HOSTNAME" => host, "GITLAB_PORT" => port }

    # On Linux, we cannot forward ports <1024
    # We need to use higher ports, and have port forward or nginx proxy
    # or access the site via hostname:<port>, in this case 127.0.0.1:8080
    # By default, Gitlab is at https + port 8443
    config.vm.network :forwarded_port, guest: 443, host: port
  end

  # GitLab recommended specs
  config.vm.provider "virtualbox" do |v, override|
    v.cpus = cpus
    v.memory = memory
  end

  config.vm.provider "vmware_fusion" do |v, override|
    v.vmx["memsize"] = "#{memory}"
    v.vmx["numvcpus"] = "#{cpus}"
    # untested, no vmware license anymore, puppetlabs' vm worked for 14.04
    override.vm.box = "puppetlabs/ubuntu-16.04-64-puppet"
  end

  config.vm.provider "parallels" do |v, override|
    v.cpus = cpus
    v.memory = memory
    # waiting for official "parallels/ubuntu-16.04" vm
    override.vm.box = "boxcutter/ubuntu1604"
  end

  config.vm.provider "lxc" do |v, override|
    override.vm.box = "developerinlondon/ubuntu_lxc_xenial_x64"
  end
end
