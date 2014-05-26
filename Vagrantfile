# -*- mode: ruby -*-
# vi: set ft=ruby :

# Author: Tuomo Tanskanen <tumi@tumi.fi>

Vagrant.configure("2") do |config|

  config.vm.define :gitlab do |config|
    # Vagrant 1.5 type box
    config.vm.box = "hashicorp/precise64"
    # config.vm.box = "chef/ubuntu-14.04"

    # Comment out if you only want CI
    config.vm.provision :shell, :path => "install-gitlab.sh"
    # Expose port 80 for Gitlab, use 443 if you manually configure SSL too
    # On Linux, you need to use 8080 or some other port and have nginx proxy 80 to that port
    config.vm.network :forwarded_port, guest: 80, host: 8080
    # config.vm.network :forwarded_port, guest: 443, host: 443
  end

  # GitLab recommended specs
  config.vm.provider "virtualbox" do |v, override|
    v.customize [ "modifyvm", :id, "--cpus", "2" ]
    v.customize [ "modifyvm", :id, "--memory", "2048" ]
  end

  config.vm.provider "vmware_fusion" do |v, override|
    v.vmx["numvcpus"] = "2"
    v.vmx["memsize"] = "2048"
  end
end
