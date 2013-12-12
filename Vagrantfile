# -*- mode: ruby -*-
# vi: set ft=ruby :

# Author: Tuomo Tanskanen <tumi@tumi.fi>

Vagrant.configure("2") do |config|

  # GitLab recommended specs
  config.vm.provider "virtualbox" do |v|
    v.customize [ "modifyvm", :id, "--cpus", "2" ]
    v.customize [ "modifyvm", :id, "--memory", "1536" ]
  end

  config.vm.define :gitlab do |gitlab|
    gitlab.vm.box = "precise64"
    gitlab.vm.box_url = "http://files.vagrantup.com/precise64.box"

    gitlab.vm.network :forwarded_port, guest: 80, host: 20080
    gitlab.vm.network :forwarded_port, guest: 3000, host: 23000
    # gitlab.vm.network :forwarded_port, guest: 443, host: 20443

    # Uncomment the ones you do not want
    gitlab.vm.provision :shell, :path => "install-gitlab.sh"
    gitlab.vm.provision :shell, :path => "install-gitlab-ci.sh"

    # CI Runner cannot be automated in a full install as it needs a token from CI
    # gitlab.vm.provision :shell, :path => "install-gitlab-ci-runner.sh"
  end

  config.vm.provider "vmware_fusion" do |v, override|
    override.vm.box = "precise64_fusion"
    override.vm.box_url = "http://files.vagrantup.com/precise64_vmware.box"
    v.vmx["numvcpus"] = "2"
    v.vmx["memsize"] = "1536"
  end
end
