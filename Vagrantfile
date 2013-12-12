# -*- mode: ruby -*-
# vi: set ft=ruby :

# Author: Tuomo Tanskanen <tumi@tumi.fi>

Vagrant.configure("2") do |config|

  # GitLab recommended specs
  config.vm.provider "virtualbox" do |v|
    v.customize [ "modifyvm", :id, "--cpus", "2" ]
    v.customize [ "modifyvm", :id, "--memory", "1536" ]
  end

  config.vm.define :gitlab do |config|
    config.vm.box = "precise64"
    config.vm.box_url = "http://files.vagrantup.com/precise64.box"

    # As default, only expose port 80 for GitLab
    config.vm.network :forwarded_port, guest: 80, host: 20080

    # Uncomment if you use SSL
    # config.vm.network :forwarded_port, guest: 443, host: 20443

    config.vm.provision :shell, :path => "install-gitlab.sh"

    # Uncomment these if you want CI too
    # config.vm.provision :shell, :path => "install-gitlab-ci.sh"
    # config.vm.network :forwarded_port, guest: 3000, host: 23000

    # CI Runner cannot be automated in a full install as it needs a token from CI
    # config.vm.provision :shell, :path => "install-gitlab-ci-runner.sh"
  end

  config.vm.provider "vmware_fusion" do |v, override|
    override.vm.box = "precise64_fusion"
    override.vm.box_url = "http://files.vagrantup.com/precise64_vmware.box"
    v.vmx["numvcpus"] = "2"
    v.vmx["memsize"] = "1536"
  end
end
