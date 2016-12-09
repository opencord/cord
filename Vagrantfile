# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  if (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    config.vm.synced_folder "..", "/cord", mount_options: ["dmode=700,fmode=600"]
  else
    config.vm.synced_folder "..", "/cord"
  end

  #By default, this variable is set to 2, such that Vagrantfile allows creation
  #of compute nodes up to 2. If the number of compute nodes to be supported more
  #than 2, set the environment variable NUM_COMPUTE_NODES to the desired value
  #before executing this Vagrantfile.
  num_compute_nodes = (ENV['NUM_COMPUTE_NODES'] || 2).to_i
  compute_ip_base = "10.6.1."
  compute_ips = num_compute_nodes.times.collect { |n| compute_ip_base + "#{n+2}" }

  config.vm.define "corddev" do |d|
    d.ssh.forward_agent = true
    d.vm.box = "ubuntu/trusty64"
    d.vm.synced_folder '.', '/vagrant', disabled: true
    d.vm.hostname = "corddev"
    d.vm.network "private_network", ip: "10.100.198.200"
    d.vm.provision :shell, path: "scripts/bootstrap_ansible.sh"
    d.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/corddev.yml -c local"
    d.vm.provider "virtualbox" do |v|
      v.memory = 2048
    end
    d.vm.provider :libvirt do |v, override|
      v.memory = 2048
      override.vm.synced_folder "..", "/cord", type: "nfs"
    end
  end

  config.vm.define "prod" do |d|
    d.vm.box = "ubuntu/trusty64"
    d.vm.synced_folder '.', '/vagrant', disabled: true
    d.vm.hostname = "prod"
    d.vm.network "forwarded_port", guest: 80, host: 8080, host_ip: '*'
    d.vm.network "private_network", ip: "10.100.198.201"
    d.vm.network "private_network",
        ip: "0.0.0.0",
        auto_config: false,
        virtualbox__intnet: "cord-mgmt-network",
        libvirt__network_name: "cord-mgmt-network",
        libvirt__forward_mode: "none",
        libvirt__dhcp_enabled: false
    d.vm.network "private_network",
        ip: "10.6.1.201", # To set up the 10.6.1.1 IP address on bridge
        virtualbox__intnet: "cord-fabric-network",
        libvirt__network_name: "cord-fabric-network",
        libvirt__forward_mode: "nat",
        libvirt__dhcp_enabled: false
    d.vm.provision :shell, path: "scripts/bootstrap_ansible.sh"
    d.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/prod.yml -c local"
    d.vm.provider "virtualbox" do |v|
      v.memory = 2048
    end
    d.vm.provider :libvirt do |v, override|
      v.memory = 24576
      v.cpus = 8
      v.storage :file, :size => '100G', :type => 'qcow2'
      override.vm.synced_folder "..", "/cord", type: "nfs"
      override.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/add-extra-drive.yml -c local"
    end
  end

  config.vm.define "switch" do |s|
    s.vm.box = "ubuntu/trusty64"
    s.vm.hostname = "fakeswitch"
    s.vm.network "private_network", ip: "10.100.198.253"
    s.vm.network "private_network",
        type: "dhcp",
        virtualbox__intnet: "cord-fabric-network",
        libvirt__network_name: "cord-fabric-network",
        mac: "cc37ab000001"
    s.vm.provision :shell, path: "scripts/bootstrap_ansible.sh"
    s.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/fakeswitch.yml -c local"
    s.vm.provider "virtualbox" do |v|
      v.memory = 1048
      v.name = "fakeswitch"
    end
  end

  config.vm.define "testbox" do |d|
    d.vm.box = "fgrehm/trusty64-lxc"
    d.ssh.forward_agent = true
    d.vm.hostname = "testbox"
    d.vm.network "private_network", ip: "10.0.3.100", lxc__bridge_name: 'lxcbr0'
    d.vm.provision :shell, path: "scripts/bootstrap_ansible.sh"
    d.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/corddev.yml -c local"
    config.vm.provider :lxc do |lxc|
        # Same effect as 'customize ["modifyvm", :id, "--memory", "1024"]' for VirtualBox
        lxc.customize 'cgroup.memory.limit_in_bytes', '2048M'
        lxc.customize 'aa_profile', 'unconfined'
        lxc.customize 'cgroup.devices.allow', 'b 7:* rwm'
        lxc.customize 'cgroup.devices.allow', 'c 10:237 rwm'
    end
  end

  num_compute_nodes.times do |n|
    config.vm.define "compute_node-#{n+1}" do |c|
      compute_ip = compute_ips[n]
      compute_index = n+1
      c.vm.synced_folder '.', '/vagrant', disabled: true
      c.vm.communicator = "none"
      c.vm.hostname = "computenode-#{compute_index}"
      c.vm.network "private_network",
        adapter: 1,
        ip: "0.0.0.0",
        auto_config: false,
        virtualbox__intnet: "cord-mgmt-network",
        libvirt__network_name: "cord-mgmt-network"
      c.vm.network "private_network",
        adapter: 2,
        ip: "#{compute_ip}",
        auto_config: false,
        virtualbox__intnet: "cord-fabric-network",
        libvirt__network_name: "cord-fabric-network",
        libvirt__forward_mode: "nat",
        libvirt__dhcp_enabled: false
      c.vm.provider :libvirt do |v|
        v.memory = 8192
        v.cpus = 4
        v.machine_virtual_size = 100
        v.storage :file, :size => '100G', :type => 'qcow2'
        v.boot 'network'
        v.boot 'hd'
        v.nested = true
      end
      c.vm.provider "virtualbox" do |v, override|
        override.vm.box = "clink15/pxe"
        v.memory = 1048
        v.gui = "true"
      end
    end
  end

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end

end
