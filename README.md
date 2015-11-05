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
  java_version: 8
  mailhog_version: 0.1.6
  mongo_version: 3
  nodejs_version: "0.12" # 0.10 0.12
  php_family: default # 5.4 | 5.5 | 5.6 | default
  php_xdebug_version: 2.3.3
  ...

  php_extensions:
    - { name: "php5-curl" }
    - { name: "php5-xsl" }    
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
     - include: "{{root_dir}}/tasks_memcached.yml"
     # Installs custom php extensions
     - include: "./tasks_phpextensions.yml"
     # (re)imports databases from db folder
     - include: "{{root_dir}}/vagrant/tasks_vagrant_import_mysqldb_databag.yml"
     # register apache websites on vagrant
     - include: "{{root_dir}}/vagrant/tasks_vagrant_apache2_devsites.yml"           
  </pre>

This installs typical LAMP stack: Apache 2.4 with PHP 5.5 (or 5.4 or 5.6 , depending on php_family set). In addition, composer and bower tools are installed.  Gulp, grunt are also available. If I need more specific setup on versions, I tune it here.


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

### Making guest projects accessible from local box.
Take a look on the following section from vagrant.yml:
<pre>
vagrant_lvh_sites:
  - { type: "web",                                                                 # WSGI & LAMP sites supported
      name: "tools",                                                               # Name of the dev website
      path: "/vagrant/public/vagrant-tools",                                       # Path to site home folder
#          template: "{{playbook_dir}}/files/apache2/website.yml",                     # Provide custom template, if builtin is not good
      aliases: [ "tools.vagrant.dev" ]                                             # These will be additional aliases to <<name>>.lvh.me
      vhost_overrides: ["SetEnv no-gzip 1", "RequestHeader unset Accept-Encoding"] # These lines will be added to website configuration file.
    }
</pre>

Configuration variable _vagrant_lvh_sites_  contains list of sites,that needs to be configured withing Vagrant.
Let me guide through parameters:
- type:  can be either web or wsgi - specifies what vhost template is used. 'web' is suitable for most of the lamp projects.
- name: unique alpha-numeric site's name. Site will be available under name <site name>.lvh.me
- path: path to the site repository root folder
- dest: optional, if repository root folder is not the website root. Specify relative path to web root here.
- template: optional, if default apache virtual host template does not suit your needs, you can override it here.
- aliases: optiona, array of domain names. Will be used as virtual host aliases. Suitable, if you plan to access vagrant on .dev domain
- vhost_overrides: optional, array of strings, list of Apache configurations that will be injected into the Apache vhost template.

<site name>.lvh.me trick:  \*.lvh.me always resolves to 127.0.0.1 ; This allows developer to use the same domain name both inside vagrant and developer's local box. Bonus - port forwarding works like a charm. You can achieve effect: by navigating to website.lvh.me you access website hosted and configured on vagrant.

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


## Troubleshouting emails
Usually sites send mails. In order to debug this part, I usually use mailhog. This is SMTP debugging tool with WebUI interface, suitable also for automatic testing. Project website: https://github.com/mailhog/MailHog

## Debugging

For some reason this most often causes difficulties. XDebug is installed inside a lamp box. It is configured to poll back originating host, so in most cases you will need just to listen for incoming debug connections (green phone in phpstorm).
In addition, you will need either some bookmarklet or extension like [XDebug Helper](https://chrome.google.com/webstore/detail/xdebug-helper/eadndfjplgieldjbigjakmdgkmoaaaoc) to turn debugging session on.

Sites inside vagrant are available:

- on lvh.me domain on port 9080 (if you are on windows, or privileged user - you can map even 80 to 80)
![lvh.me](https://raw.githubusercontent.com/Voronenko/lamp-box/master/docs/tools_lvh.jpg)
- on vagrant.dev domain on port 80
![vagrant.dev](https://raw.githubusercontent.com/Voronenko/lamp-box/master/docs/tools_dev.jpg)

Typical steps to debug using phpstorm include:

- configuring interpreter (you can use either local or remote one). PHPStorm 9.0.2 will automatically detect vagrant, btw.
![remote intepreter](https://raw.githubusercontent.com/Voronenko/lamp-box/master/docs/phpstorm_remoteinterpreter.jpg)

- turning on listen for debug connections (phpstorm) + ensuring setting debug session in browser
![remote intepreter](https://github.com/Voronenko/lamp-box/blob/master/docs/phpstorm_debug_on.jpg)

- putting breakpoint inside your code and actually debug. Note: root of the lamp-box repository is mapped to /vagrant/
![remote intepreter](https://raw.githubusercontent.com/Voronenko/lamp-box/master/docs/debug_process_example.jpg)


## Code in action

Code can be downloaded from repository [https://github.com/Voronenko/lamp-box](https://github.com/Voronenko/lamp-box "https://github.com/Voronenko/lamp-box")

### Prepare
Checkout or fork repository. Run ./init_vagrant.sh to install vagrant plugins if you do not have them already.

Adjust .projmodules to include project repositories you are going to wrap. If necessary, implement ansible recipe to configure some specific project environment which go beyond installing php extensions.

Run ./init.sh to clone necessary project repositories. Do not remove "public/ansible_developer_recipes" project, because it is required for environment setup.

Review deployment/vagrant.yml to ensure it includes everything you planned to install.

### Provision environment.

Run _vagrant up_ and be patient. You are configuring new box, so it may take a while. Speed depends on your internet connectivity. In rare case provision  might be interrupted. In this case repeat provisioning manually using _vagrant provision_ command.

Finally you should see smth like this:
<pre>
PLAY RECAP ********************************************************************
default                    : ok=46   changed=16   unreachable=0    failed=0  
</pre>

At this moment you have additional helpers:
- Mailhog web ui interface at http://localhost:9025/ or at http://tools.vagrant.dev:8025/
- PHPMyAdmin web ui: under each site in /phpmyadmin/ subfolder. Use root / devroot to login. (As you recall, your project dbs are imported automatically once at initial provision)
- WebGrind profiler: under each site in /webgrind/ subfolder.
- Configured debugger.

## Points of interest

Everyone has it's own recopes how to build best web development environment in the world. The best one is that suits your needs. I prefer to have only minimal set of software on my work PC that's I widely adopt virtualization with Vagrant and ESXi. Goal is to have robust way to run multiple projects on my host without interference. With ESZXi and Vagrant I successfully can accomplish the goal.
