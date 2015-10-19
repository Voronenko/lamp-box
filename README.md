# Wrapping LAMP project into Vagrant with ansible

## Background

As a contractor software developer I am asked from time to time to perform audit of LAMP projects. As project configuration is different, I use so-called "umbrella repository environment" which allows me to wrap such projects into reusable vagrant environment without need to amend audited projects codebase itself.

Let me share this approach with you.

Tools are simple: Oracle Virtual Box, Vagrant with several additional plugins, Git, "Ansible Developer recipes" items collection. Windows is supported, if you have Git For Windows (ex MSysGit) installed.
Vagrant box is provisioned with Ansible, as this provision tool has minimal dependencies to run.

## Challenges to address
- configure vagrant environment on local box
- configure guest OS (I usually work with Ubuntu 14.04 LTS distribution) with LAMP stack
- checkout guest projects into workplace & map tham into vagrant
- provision guest OS according to guest projects requirements
- Ensure guest projects are accessible from local box
- Do your work


### Prepare vagrant environment

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

### Getting LAMP on Vagrant
In order to configure LAMP stack on vagrant, I use Ansible provisioner and set of provisioning recipes.

Let's take a look on deployment/vagrant.yml parts:

<pre>
vars:
  ...
  mysql_root_user: root
  mysql_root_password: devroot
  apache_mode: prefork # use prefork or worker variables
  php_family: "5.4"
  nodejs_version: "0.12" # 0.10 0.12
  ...

  php_extensions:
    - { name: "php5-curl" }
    - { name: "php5-memcache" }
    - { name: "php5-memcached" }

 ...  

  tasks:
       # MySQL 5.5
     - include: "{{root_dir}}/tasks_mysql.yml"
       # apache prefork|worker     
     - include: "{{root_dir}}/tasks_apache.yml"                                     
     - include: "{{root_dir}}/tasks_php_apt_switchversion.yml"
     # php 5.5 for apache
     - include: "{{root_dir}}/tasks_php_apache.yml"
     # node 0.12.*
     - include: "{{root_dir}}/tasks_nodejs.yml"
     # installs memcached service     
     - include: "{{root_dir}}/tasks_memcached.yml"                                  # Installs custom php extensions
     - include: "./tasks_phpextensions.yml"                                         # (re)imports databases from db folder
     - include: "{{root_dir}}/vagrant/tasks_vagrant_import_mysqldb_databag.yml"     # register apache websites on vagrant
     - include: "{{root_dir}}/vagrant/tasks_vagrant_apache2_devsites.yml"           </pre>
This installs typical LAMP stack: Apache 2.4 with PHP 5.5 (or 5.4 or 5.6 , depending on php_family set). In addition, composer and bower tools are installed.  Gulp, grunt are also available.


### Getting guest projects into vagrant
In order to get projects inside vagrant, let's checkout them into public folder. Public folder is than mapped as /vagrant/public inside vagrant box. Due to some permissions limitations, we map folders with 777 access rights and files with 666.
<pre>
c.vm.synced_folder ".", "/vagrant", mount_options: ['dmode=777','fmode=666']
</pre>

Usually guest projects are hosted in their own repositories. To speed up checkout for such case, special file was introduced, called .projmodules. Format is compatible with gitmodules file format, typically looks like series of the project definitions:
<pre>
[submodule "public/ansible_developer_recipes"]
	path = public/ansible_developer_recipes
	url = git@github.com:Voronenko/ansible-developer_recipes.git
</pre>

Each sub project will be cloned into _path_ using repository address _url_

init.sh provided withing repository installs or reinstalls guest projects.

### Overriding guest projects configuration for vagrant.
This could be really tricky. Mine recommendation, is to keep under local/ subfolder files that needs to be overwritten for working with vagrant. For example, if guest project has config in public/proj1/config/  , we can have overrides in local/proj1/config/local_config_file_adjusted_for_vagrant.php ; In this case adjusting codebase to work under vagrant is as easy as copying contents of the local folder over the public. If guest project architecture allows environment or development based configuration that's the best scenario.


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


## Code in action

Code can be downloaded from repository [https://github.com/Voronenko/lamp-box](https://github.com/Voronenko/lamp-box "https://github.com/Voronenko/lamp-box")



## Points of interest
