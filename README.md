Wrapping LAMP project into Vagrant with ansible
===============================================



#Background

# Challenges to address

## vagrant environment

There are tons of vagrant plugins. Some of them are quite handy.
Usually I am using three plugins with vagrant:

- vagrant-vbguest: Synhronizes guest additions versions inside image  with the master Oracle VirtualBox version. This helps to prevent random issues with shared folders.
- vagrant-hostsupdater: Automatically updates host files with side dev aliases used. Important: this plugin will ask you for privileged access to write into /etc/hosts.  
- vagrant-auto_network: This plugin registers an internal address range and assigns unique IP addresses for each successive request so that network configuration is entirely hands off. It's much lighter than running a DNS server and masks the underlying work of manually assigning addresses.

With plugins above, my Vagrantfile usually contains: aliases for dev websites to be added to /etc/hosts + I prefer all Vagrant boxes to have the same IP address subnetwork.
<pre>
config.vm.hostname = "www.local.dev"
config.hostsupdater.aliases = ["alias.local.dev", "alias2.local.dev"]
config.vm.network :private_network, :auto_network => true

# My favorite:  to stick to 33.* subnetwork
AutoNetwork.default_pool = '192.168.33.0/24'
</pre>

init_vagrant.sh provided within repository installs mentioned plugins.

## Importing mysql database dumps

There are two approaches:
- Option A : vagrant connects to mysql running on your local computer/network.
This is easiest approach, in this case it is not necessary to install mysql under Vagrant.

- Option B: mysql is installed inside vagrant, and we need way to import databases.

For the purposes of the running mysql under vagrant:
put your sql dumps under databag/db/<database name>/<database dump>.sql ; For example, databag/db/website/dump.sql

Provisioning recipe will import each of the available database dumps as a new database, assuming
folder name equals database name. If .nodbs flag file is found in the databag/db root, import is skipped to prevent accidental DB overwriting.

Script below does the trick:
<pre>
#!/bin/sh

HOMEDIR=${PWD}

if [ -f .nodbs ] ; then
    echo ".nodbs flag present, db import skipped";
    exit 0
fi

for d in */ ; do
    DBNAME="$(echo $d | cut -d '=' -f 2 | sed 's/\/$//')"
    echo "IMPORTING DB: $DBNAME"
    cd "$HOMEDIR/$DBNAME"
    mysql -u{{mysql_root_user}}  -p{{mysql_root_password}} -e "drop database if exists $DBNAME"
    mysql -u{{mysql_root_user}}  -p{{mysql_root_password}} -e "create database if not exists $DBNAME CHARACTER SET utf8 COLLATE utf8_general_ci"    
    last_dump=$(find ./*.sql -type f -exec stat -c "%n" {} + | sort -r | head -n1)
    mysql -u{{mysql_root_user}} -p{{mysql_root_password}} $DBNAME< $last_dump
done

touch "$HOMEDIR/.nodbs"
</pre>


#Code in action

Code can be downloaded from repository [https://github.com/Voronenko/Storing_TreeView_Structures_WithMongoDB](https://github.com/Voronenko/Storing_TreeView_Structures_WithMongoDB "https://github.com/Voronenko/Storing_TreeView_Structures_WithMongoDB")



#Points of interest
