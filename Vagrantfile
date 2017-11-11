# -*- mode: ruby -*-
# vi: set ft=ruby :
# Copyright (c) 2013-2017 Tuomo Tanskanen <tuomo@tanskanen.org>

# read configurable cpu/memory/port/swap/host/edition settings from environment variables
memory = ENV['GITLAB_MEMORY'] || 3072
cpus = ENV['GITLAB_CPUS'] || 1
port = ENV['GITLAB_PORT'] || 8443
swap = ENV['GITLAB_SWAP'] || 0
host = ENV['GITLAB_HOST'] || "gitlab.local"
edition = ENV['GITLAB_EDITION'] || "community"

Vagrant.require_version ">= 1.8.0"

Vagrant.configure("2") do |config|

  config.vm.define :gitlab do |config|
    # Configure some hostname here
    config.vm.hostname = host
	# bento/ubuntu-16.04 provides boxes for virtualbox. vmware_desktop(fusion, workstation) and parallels
    config.vm.box = "bento/ubuntu-16.04"
    config.vm.provision :shell, :path => "install-gitlab.sh",
      env: { "GITLAB_SWAP" => swap, "GITLAB_HOSTNAME" => host, "GITLAB_PORT" => port, "GITLAB_EDITION" => edition }

    # On Linux, we cannot forward ports <1024
    # We need to use higher ports, and have port forward or nginx proxy
    # or access the site via hostname:<port>, in this case 127.0.0.1:8080
    # By default, Gitlab is at https + port 8443
    config.vm.network :forwarded_port, guest: 443, host: port

    # use rsync for synced folder to avoid the need for provider tools
	# added rsync__auto  to enable detect changes on host and sync to guest machine and exclude .git/
    config.vm.synced_folder ".", "/vagrant", type: "rsync", rsync__exclude: ".git/", rsync__auto: true
  end

  # GitLab recommended specs
  config.vm.provider "virtualbox" do |v|
    v.cpus = cpus
    v.memory = memory
  end
  
  # vmware Workstation and Fusion Provider this will work for both vmware versions as the virtual machines
  # images are identical is a fuzzy term which will allow both to work effecively for ether Fusion for the
  # Mac or Workstation for the PC. It only matters which provider is specified on vagrant up command
  # (--provider=vmware_fusion or --provider=vmware_workstation)
  # vmware provieder requires hashicorp license https://www.vagrantup.com/vmware/index.html
  config.vm.provider "vmware_desktop" do |v|
	v.vmx["memsize"] = "#{memory}"
	v.vmx["numvcpus"] = "#{cpus}"
  end
  
  config.vm.provider "parallels" do |v|
    v.cpus = cpus
    v.memory = memory
  end

  config.vm.provider "lxc" do |v, override|
    override.vm.box = "developerinlondon/ubuntu_lxc_xenial_x64"
  end
end
