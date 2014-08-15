# -*- mode: ruby -*-
# vi: set ft=ruby :
# Author: Tuomo Tanskanen <tuomo@tanskanen.org>

Vagrant.require_version ">= 1.5.0"

Vagrant.configure("2") do |config|

  config.vm.define :gitlab do |config|
    # Configure some hostname here
    # config.vm.hostname = "gitlab.invalid"
    config.vm.box = "hashicorp/precise64"
    config.vm.provision :shell, :path => "install-gitlab.sh"

    # On Linux, we cannot forward ports <1024
    # We need to use 8080 or some other port and have nginx proxy 80 to that port
    # or access the site via hostname:<port>, in this case 127.0.0.1:8443
    config.vm.network :forwarded_port, guest: 80, host: 8080
    config.vm.network :forwarded_port, guest: 443, host: 8443
  end

  # cache the 200M omnibus package
  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.enable :generic, { :cache_dir => "/var/cache/generic" }
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
