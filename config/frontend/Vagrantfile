Vagrant.configure("2") do |config|
  # base image
  config.vm.box = "ubuntu/trusty64"

  # share the folder
  config.vm.synced_folder "../../", "/home/vagrant/cord/", create: true
  config.vm.synced_folder "./cord_profile", "/home/vagrant/cord_profile/", create: true
  config.vm.synced_folder ".", "/vagrant", disabled: true

  # set the frontend vm
  config.vm.define "head-node" do |d|
    d.vm.network "forwarded_port", guest: 9999, host: 9999
    d.vm.network "forwarded_port", guest: 6379, host: 6379
    d.vm.network "private_network", ip: "192.168.46.100"
    d.vm.provider "virtualbox" do |vb|
      vb.memory = "4096"
      vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
      vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
    end
  end

  config.vm.provision "shell", privileged: false, inline: <<-SHELL
    # Setup CORD tools
    curl -o ~/cord-bootstrap.sh https://raw.githubusercontent.com/opencord/platform-install/master/scripts/cord-bootstrap.sh
    bash cord-bootstrap.sh
    ssh-keygen -t rsa -N "" -f .ssh/id_rsa
    cp ~/.ssh/id_rsa node_key

    # Install apache
    sudo apt-get update
    sudo apt-get install -y apache2 libapache2-mod-fastcgi apache2-mpm-worker
    sudo a2enmod proxy_http
    sudo a2enmod headers
    sudo a2enmod rewrite
    sudo a2enmod proxy_wstunnel

    # Copy apache conf
    sudo cp /home/vagrant/cord/build/platform-install/roles/head-prologue/files/cord-http.conf /etc/apache2/conf-enabled/cord-http.conf

    # Reload Apache
    sudo service apache2 reload

    # Add hosts
    echo "127.0.0.1 xos" | sudo tee --append /etc/hosts > /dev/null
    echo "127.0.0.1 xos-spa-gui" | sudo tee --append /etc/hosts > /dev/null
    echo "127.0.0.1 xos-rest-gw" | sudo tee --append /etc/hosts > /dev/null
    echo "127.0.0.1 xos-chameleon" | sudo tee --append /etc/hosts > /dev/null
    echo "127.0.0.1 xos-core" | sudo tee --append /etc/hosts > /dev/null
  SHELL

 end
