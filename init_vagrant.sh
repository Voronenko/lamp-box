#!/bin/sh
# Synhronizes guest additions versions inside image  with the master Oracle VirtualBox version
 vagrant plugin install vagrant-vbguest

 # Automatically updates host files with side dev aliases used
 # Example:
 # config.vm.hostname = "www.local.dev"
 # config.hostsupdater.aliases = ["alias.local.dev", "alias2.local.dev"]
 # Important: this plugin will ask you for privileged access to write into /etc/hosts
 vagrant plugin install vagrant-hostsupdater


 # This plugin registers an internal address range and assigns unique IP addresses 
 # for each successive request so that network configuration is entirely hands off. 
 # It's much lighter than running a DNS server and masks the underlying work of manually assigning addresses.
 # Example:
 # config.vm.network :private_network, :auto_network => true
 # My favorite:  to stick to 33.* subnetwork
 # AutoNetwork.default_pool = '192.168.33.0/24'
 vagrant plugin install vagrant-auto_network
