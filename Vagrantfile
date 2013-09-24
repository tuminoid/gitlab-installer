# -*- mode: ruby -*-
# vi: set ft=ruby :

# Author: Tuomo Tanskanen <tumi@tumi.fi>

Vagrant.configure("2") do |config|
  config.vm.provider "virtualbox" do |v|
    v.customize [ "modifyvm", :id, "--cpus", "4" ]
    v.customize [ "modifyvm", :id, "--memory", "1536" ]
  end

  config.vm.define :gitlab do |gitlab|
    gitlab.vm.box = "precise64"
    gitlab.vm.box_url = "http://files.vagrantup.com/precise64.box"

    gitlab.vm.network :forwarded_port, guest: 80, host: 20080
    # gitlab.vm.network :forwarded_port, guest: 443, host: 20443

    gitlab.vm.provision :shell, :path => "install-gitlab.sh"
  end
end
