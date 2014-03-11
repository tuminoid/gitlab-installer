# -*- mode: ruby -*-
# vi: set ft=ruby :

# Author: Tuomo Tanskanen <tumi@tumi.fi>

Vagrant.configure("2") do |config|

  config.vm.define :gitlab do |config|
    # Vagrant 1.5 type box
    config.vm.box = "hashicorp/precise64"

    # Comment out if you only want CI
    config.vm.provision :shell, :path => "install-gitlab.sh"
    # Expose port 80 for Gitlab, use 443 if you manually configure SSL too
    config.vm.network :forwarded_port, guest: 80, host: 80
    # config.vm.network :forwarded_port, guest: 443, host: 443

    # Uncomment these if you want Gitlab CI
    # config.vm.provision :shell, :path => "install-gitlab-ci.sh"
    # config.vm.network :forwarded_port, guest: 3000, host: 3000

    # CI Runner cannot be automated in a full install as it needs a token from CI
    # Install it (from here to by hand), then go to ~gitlab_ci_runner/gitlab-ci-runner
    # and execute as root: "../register-runner.sh <token>"
    # config.vm.provision :shell, :path => "install-gitlab-ci-runner.sh"
  end

  # GitLab recommended specs
  config.vm.provider "virtualbox" do |v, override|
    v.customize [ "modifyvm", :id, "--cpus", "2" ]
    v.customize [ "modifyvm", :id, "--memory", "1536" ]
  end

  config.vm.provider "vmware_fusion" do |v, override|
    v.vmx["numvcpus"] = "2"
    v.vmx["memsize"] = "1536"
  end
end
