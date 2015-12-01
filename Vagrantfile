VAGRANTFILE_API_VERSION = "2"
VAGRANT_NETWORK_IP = "192.168.33.10"

Vagrant.require_version ">= 1.7.0"

Vagrant.configure(VAGRANTFILE_API_VERSION) do |c|
  c.vm.box = "ubuntu/trusty64"
  c.vm.hostname = "precise64.vsdev"

  c.hostsupdater.aliases = ["tools.vagrant.dev"]


  c.vm.network(:forwarded_port, {:guest=>80, :host=>8080}) #http
  c.vm.network(:forwarded_port, {:guest=>8443, :host=>8443}) #ssl
  c.vm.network(:forwarded_port, {:guest=>3306, :host=>9306}) #mysql
  c.vm.network(:forwarded_port, {:guest=>8025, :host=>9025}) #mail UI

  # Create a private network, which allows host-only access to the machine
  # using a specific IP.
  c.vm.network :private_network, ip: VAGRANT_NETWORK_IP

  # Set share folder permissions to 777 so that apache can write files
  c.vm.synced_folder ".", "/vagrant", mount_options: ['dmode=777','fmode=666']

  c.vm.provider :virtualbox do |p|
#    p.gui = true
    p.customize ["modifyvm", :id, "--memory", "1024"]
    p.customize ["modifyvm", :id, "--cpuexecutioncap", "80"]
    p.customize ["setextradata", :id, "VBoxInternal2/SharedFoldersEnableSymlinksCreate/vagrant", "1"]

  end

  # Ansible can be commented after first use
  c.vm.provision "shell" do |s|
    s.inline = "apt-add-repository ppa:ansible/ansible -y; apt-get update -y; apt-get install install software-properties-common -y; apt-get -y install ansible;"
    s.privileged = true
  end

  # Comment it after first use
  c.vm.provision "shell" do |s|
    s.inline = "echo fs.inotify.max_user_watches=65535 | sudo tee -a /etc/sysctl.conf && sudo sysctl -p"
    s.privileged = true
  end


  c.vm.provision "ansible" do |ansible|
    ansible.playbook = "./deployment/vagrant.yml"
  end

  c.vm.provision "ansible_update", type: "ansible", run: "always" do |ansible|
    ansible.playbook = "./deployment/vagrant.yml"
    ansible.tags = "update"
  end

end
