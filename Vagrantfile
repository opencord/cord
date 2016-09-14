# -*- mode: ruby -*-
# vi: set ft=ruby :

Vagrant.configure(2) do |config|

  if (/cygwin|mswin|mingw|bccwin|wince|emx/ =~ RUBY_PLATFORM) != nil
    config.vm.synced_folder "..", "/cord", mount_options: ["dmode=700,fmode=600"]
  else
    config.vm.synced_folder "..", "/cord"
  end

  config.vm.define "corddev" do |d|
    d.ssh.forward_agent = true
    d.vm.box = "ubuntu/trusty64"
    d.vm.hostname = "corddev"
    d.vm.network "private_network", ip: "10.100.198.200"
    d.vm.provision :shell, path: "scripts/bootstrap_ansible.sh"
    d.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/corddev.yml -c local"
    d.vm.provider "virtualbox" do |v|
      v.memory = 2048
    end
    d.vm.provider :libvirt do |domain|
      d.vm.synced_folder '../', '/cord', type: 'rsync', rsync__args: ["--verbose", "--archive", "--delete", "-z"]
      d.vm.synced_folder '.', '/vagrant', type: 'rsync', disabled: true
      domain.memory = 2048
    end
  end

  config.vm.define "prod" do |d|
    d.vm.box = "ubuntu/trusty64"
    d.vm.synced_folder '.', '/vagrant', disable: true
    d.vm.hostname = "prod"
    d.vm.network "private_network", ip: "10.100.198.201"
    d.vm.network "private_network", ip: "0.0.0.0", virtualbox__intnet: "cord-test-network"
    d.vm.provision :shell, path: "scripts/bootstrap_ansible.sh"
    d.vm.provision :shell, inline: "PYTHONUNBUFFERED=1 ansible-playbook /cord/build/ansible/prod.yml -c local"
    d.vm.provider "virtualbox" do |v|
      v.memory = 2048
    end
  end

  config.vm.define "switch" do |s|
    s.vm.box = "ubuntu/trusty64"
    s.vm.hostname = "fakeswitch"
    s.vm.network "private_network", ip: "10.100.198.253"
    s.vm.network "private_network",
        type: "dhcp",
        virtualbox__intnet: "cord-test-network",
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

  (1..3).each do |i|
    # Defining VM properties
    config.vm.define "compute_node#{i}" do |c|
      c.vm.box = "clink15/pxe"
      c.vm.synced_folder '.', '/vagrant', disable: true
      c.vm.communicator = "none"
      c.vm.hostname = "computenode"
      c.vm.network "private_network",
        adapter: "1",
        type: "dhcp",
        auto_config: false,
        virtualbox__intnet: "cord-test-network"
      c.vm.provider "virtualbox" do |v|
        v.name = "compute_node#{i}"
        v.memory = 1048
        v.gui = "true"
      end
    end
  end

  # Libvirt compute node
  # Not able to merge with virtualbox config for compute nodes above
  # Issue is that here no box and no private network are specified
  config.vm.define "compute_node" do |c|
    c.vm.synced_folder '.', '/vagrant', disable: true
    c.vm.communicator = "none"
    c.vm.hostname = "computenode"
    c.vm.network "public_network",
      adapter: 1,
      auto_config: false,
      dev: "mgmtbr",
      mode: "bridge",
      type: "bridge"
    c.vm.provider :libvirt do |domain|
      domain.memory = 8192
      domain.cpus = 4
      domain.machine_virtual_size = 100
      domain.storage :file, :size => '100G', :type => 'qcow2'
      domain.boot 'network'
      domain.boot 'hd'
      domain.nested = true
    end
  end

  if Vagrant.has_plugin?("vagrant-cachier")
    config.cache.scope = :box
  end

end
