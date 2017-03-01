# -*- mode: ruby -*-
# vi: set ft=ruby :

$cordpath = "../../.."

Vagrant.configure(2) do |config|

  if (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    config.vm.synced_folder $cordpath, "/cord", mount_options: ["dmode=700,fmode=600"]
  else
    config.vm.synced_folder $cordpath, "/cord"
  end
  config.vm.synced_folder '.', '/vagrant', disabled: true

  config.vm.define "corddev" do |d|
    d.ssh.forward_agent = true
    d.vm.box = "ubuntu/trusty64"
    d.vm.hostname = "corddev"
    d.vm.network "private_network", ip: "10.100.198.200"
    d.vm.provision :shell, path: $cordpath + "/build/scripts/bootstrap_ansible.sh"
    d.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/corddev.yml -c local"
    d.vm.provider "virtualbox" do |v|
      v.memory = 2048
    end
    d.vm.provider :libvirt do |v, override|
      v.memory = 2048
      override.vm.synced_folder $cordpath, "/cord", type: "nfs"
    end
  end

  config.vm.define "prod" do |d|
    d.vm.box = "ubuntu/trusty64"
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
        ip: "0.1.0.0",
        mac: "02420a060101",
        auto_config: false,
        virtualbox__intnet: "head-node-leaf-1",
        libvirt__network_name: "head-node-leaf-1",
        libvirt__forward_mode: "none",
        libvirt__dhcp_enabled: false
    d.vm.provision :shell, path: $cordpath + "/build/scripts/bootstrap_ansible.sh"
    d.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/prod.yml -c local"
    d.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 cd /cord/build/platform-install; ansible-playbook -i inventory/head-localhost deploy-elasticstack-playbook.yml"
    d.vm.provider "virtualbox" do |v|
      v.memory = 2048
    end
    d.vm.provider :libvirt do |v, override|
      v.memory = 24576
      v.cpus = 8
      v.storage :file, :size => '100G', :type => 'qcow2'
      override.vm.synced_folder $cordpath, "/cord", type: "nfs"
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
    s.vm.provision :shell, path: $cordpath + "/build/scripts/bootstrap_ansible.sh"
    s.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/fakeswitch.yml -c local"
    s.vm.provider "virtualbox" do |v|
      v.memory = 1048
      v.name = "fakeswitch"
    end
  end

  config.vm.define "leaf-1" do |s|
    s.vm.box = "ubuntu/trusty64"
    s.vm.hostname = "leaf-1"
    s.vm.network "private_network",
      #type: "dhcp",
      ip: "0.0.0.0",
      auto_config: false,
      virtualbox__intnet: "cord-mgmt-network",
      libvirt__network_name: "cord-mgmt-network",
      mac: "cc37ab000011"
    s.vm.network "private_network",
      ip: "0.1.0.0",
      auto_config: false,
      virtualbox__intnet: "head-node-leaf-1",
      libvirt__network_name: "head-node-leaf-1",
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false
    s.vm.network "private_network",
      ip: "0.2.0.0",
      auto_config: false,
      virtualbox__intnet: "compute-node-1-leaf-1",
      libvirt__network_name: "compute-node-1-leaf-1",
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false
    s.vm.network "private_network",
      ip: "0.5.0.0",
      auto_config: false,
      virtualbox__intnet: "leaf-1-spine-1",
      libvirt__network_name: "leaf-1-spine-1",
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false
    s.vm.network "private_network",
      ip: "0.6.0.0",
      auto_config: false,
      virtualbox__intnet: "leaf-1-spine-2",
      libvirt__network_name: "leaf-1-spine-2",
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false
    s.vm.provision :shell, path: $cordpath + "/build/scripts/bootstrap_ansible.sh"
    if (ENV['FABRIC'] == "1")
      s.vm.provision :shell, path: $cordpath + "/build/scripts/install.sh", args: "-3f"
      s.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/leafswitch.yml -c local -e 'fabric=true net_prefix=10.6.1'"
    else
      s.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/leafswitch.yml -c local -e 'net_prefix=10.6.1'"
    end
    s.vm.provider :libvirt do |v, override|
        v.memory = 512
        v.cpus = 1
        override.vm.synced_folder $cordpath, "/cord", type: "nfs"
    end
    s.vm.provider "virtualbox" do |v, override|
        v.memory = 512
        v.cpus = 1
    end
  end

  config.vm.define "leaf-2" do |s|
    s.vm.box = "ubuntu/trusty64"
    s.vm.hostname = "leaf-2"
    s.vm.network "private_network",
      #type: "dhcp",
      ip: "0.0.0.0",
      auto_config: false,
      virtualbox__intnet: "cord-mgmt-network",
      libvirt__network_name: "cord-mgmt-network",
      mac: "cc37ab000012"
    s.vm.network "private_network",
      ip: "0.3.0.0",
      auto_config: false,
      virtualbox__intnet: "compute-node-2-leaf-2",
      libvirt__network_name: "compute-node-2-leaf-2",
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false
    s.vm.network "private_network",
      ip: "0.4.0.0",
      auto_config: false,
      virtualbox__intnet: "compute-node-3-leaf-2",
      libvirt__network_name: "compute-node-3-leaf-2",
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false
    s.vm.network "private_network",
      ip: "0.7.0.0",
      auto_config: false,
      virtualbox__intnet: "leaf-2-spine-1",
      libvirt__network_name: "leaf-2-spine-1",
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false
    s.vm.network "private_network",
      ip: "0.8.0.0",
      auto_config: false,
      virtualbox__intnet: "leaf-2-spine-2",
      libvirt__network_name: "leaf-2-spine-2",
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false
    s.vm.provision :shell, path: $cordpath + "/build/scripts/bootstrap_ansible.sh"
    if (ENV['FABRIC'] == "1")
      s.vm.provision :shell, path: $cordpath + "/build/scripts/install.sh", args: "-3f"
      s.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/leafswitch.yml -c local -e 'fabric=true net_prefix=10.6.1'"
    else
      s.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/leafswitch.yml -c local -e 'net_prefix=10.6.1'"
    end
    s.vm.provider :libvirt do |v, override|
        v.memory = 512
        v.cpus = 1
        override.vm.synced_folder $cordpath, "/cord", type: "nfs"
    end
    s.vm.provider "virtualbox" do |v, override|
        v.memory = 512
        v.cpus = 1
    end
  end

  config.vm.define "spine-1" do |s|
    s.vm.box = "ubuntu/trusty64"
    s.vm.hostname = "spine-1"
    s.vm.network "private_network",
      #type: "dhcp",
      ip: "0.0.0.0",
      auto_config: false,
      virtualbox__intnet: "cord-mgmt-network",
      libvirt__network_name: "cord-mgmt-network",
      mac: "cc37ab000021"
    s.vm.network "private_network",
      ip: "0.5.0.0",
      auto_config: false,
      virtualbox__intnet: "leaf-1-spine-1",
      libvirt__network_name: "leaf-1-spine-1",
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false
    s.vm.network "private_network",
      ip: "0.7.0.0",
      auto_config: false,
      virtualbox__intnet: "leaf-2-spine-1",
      libvirt__network_name: "leaf-2-spine-1",
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false
    s.vm.provision :shell, path: $cordpath + "/build/scripts/bootstrap_ansible.sh"
    if (ENV['FABRIC'] == "1")
      s.vm.provision :shell, path: $cordpath + "/build/scripts/install.sh", args: "-3f"
      s.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/spineswitch.yml -c local -e 'fabric=true net_prefix=10.6.1'"
    else
      s.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/spineswitch.yml -c local -e 'net_prefix=10.6.1'"
    end
    s.vm.provider :libvirt do |v, override|
        v.memory = 512
        v.cpus = 1
        override.vm.synced_folder $cordpath, "/cord", type: "nfs"
    end
    s.vm.provider "virtualbox" do |v, override|
        v.memory = 512
        v.cpus = 1
    end
  end

  config.vm.define "spine-2" do |s|
    s.vm.box = "ubuntu/trusty64"
    s.vm.hostname = "spine-2"
    s.vm.network "private_network",
      #type: "dhcp",
      ip: "0.0.0.0",
      auto_config: false,
      virtualbox__intnet: "cord-mgmt-network",
      libvirt__network_name: "cord-mgmt-network",
      mac: "cc37ab000022"
    s.vm.network "private_network",
      ip: "0.6.0.0",
      auto_config: false,
      virtualbox__intnet: "leaf-1-spine-2",
      libvirt__network_name: "leaf-1-spine-2",
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false
    s.vm.network "private_network",
      ip: "0.8.0.0",
      auto_config: false,
      virtualbox__intnet: "leaf-2-spine-2",
      libvirt__network_name: "leaf-2-spine-2",
      libvirt__forward_mode: "none",
      libvirt__dhcp_enabled: false
    s.vm.provision :shell, path: $cordpath + "/build/scripts/bootstrap_ansible.sh"
    if (ENV['FABRIC'] == "1")
      s.vm.provision :shell, path: $cordpath + "/build/scripts/install.sh", args: "-3f"
      s.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/spineswitch.yml -c local -e 'fabric=true net_prefix=10.6.1'"
    else
      s.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/spineswitch.yml -c local -e 'net_prefix=10.6.1'"
    end
    s.vm.provider :libvirt do |v, override|
        v.memory = 512
        v.cpus = 1
        override.vm.synced_folder $cordpath, "/cord", type: "nfs"
    end
    s.vm.provider "virtualbox" do |v, override|
        v.memory = 512
        v.cpus = 1
    end
  end

  config.vm.define "testbox" do |d|
    d.vm.box = "fgrehm/trusty64-lxc"
    d.ssh.forward_agent = true
    d.vm.hostname = "testbox"
    d.vm.network "private_network", ip: "10.0.3.100", lxc__bridge_name: 'lxcbr0'
    d.vm.provision :shell, path: $cordpath + "/build/scripts/bootstrap_ansible.sh"
    d.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/corddev.yml -c local"
    config.vm.provider :lxc do |lxc|
        # Same effect as 'customize ["modifyvm", :id, "--memory", "1024"]' for VirtualBox
        lxc.customize 'cgroup.memory.limit_in_bytes', '2048M'
        lxc.customize 'aa_profile', 'unconfined'
        lxc.customize 'cgroup.devices.allow', 'b 7:* rwm'
        lxc.customize 'cgroup.devices.allow', 'c 10:237 rwm'
    end
  end

  config.vm.define "compute-node-1" do |c|
    c.vm.communicator = "none"
    c.vm.hostname = "compute-node-1"
    c.vm.network "private_network",
      adapter: 1,
      ip: "0.0.0.0",
      auto_config: false,
      virtualbox__intnet: "cord-mgmt-network",
      libvirt__network_name: "cord-mgmt-network"
    c.vm.network "private_network",
      adapter: 2,         # The fabric interface for each node
      ip: "0.2.0.0",
      auto_config: false,
      virtualbox__intnet: "compute-node-1-leaf-1",
      libvirt__network_name: "compute-node-1-leaf-1",
      libvirt__forward_mode: "none",
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

  config.vm.define "compute-node-2" do |c|
    c.vm.communicator = "none"
    c.vm.hostname = "compute-node-2"
    c.vm.network "private_network",
      adapter: 1,
      ip: "0.0.0.0",
      auto_config: false,
      virtualbox__intnet: "cord-mgmt-network",
      libvirt__network_name: "cord-mgmt-network"
    c.vm.network "private_network",
      adapter: 2,         # The fabric interface for each node
      ip: "0.3.0.0",
      auto_config: false,
      virtualbox__intnet: "compute-node-2-leaf-2",
      libvirt__network_name: "compute-node-2-leaf-2",
      libvirt__forward_mode: "none",
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

  config.vm.define "compute-node-3" do |c|
    c.vm.communicator = "none"
    c.vm.hostname = "compute-node-3"
    c.vm.network "private_network",
      adapter: 1,
      ip: "0.0.0.0",
      auto_config: false,
      virtualbox__intnet: "cord-mgmt-network",
      libvirt__network_name: "cord-mgmt-network"
    c.vm.network "private_network",
      adapter: 2,         # The fabric interface for each node
      ip: "0.4.0.0",
      auto_config: false,
      virtualbox__intnet: "compute-node-3-leaf-2",
      libvirt__network_name: "compute-node-3-leaf-2",
      libvirt__forward_mode: "none",
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

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end

end
