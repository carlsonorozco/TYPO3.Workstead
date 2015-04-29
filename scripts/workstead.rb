class Workstead
	def Workstead.configure(config, settings)
		# set vm provider
		ENV['VAGRANT_DEFAULT_PROVIDER'] = settings["provider"] ||= "virtualbox"

		# configure local variable to access scripts from remote location
		scriptDir = File.dirname(__FILE__)

		# prevent tty errors
		config.ssh.shell = "bash -c 'BASH_ENV=/etc/profile exec bash'"

		# configure the box
		config.vm.box = "ubuntu/trusty64"
		config.vm.hostname = "workstead"

		# configure a private network IP
		config.vm.network :private_network, ip: settings["ip"] ||= "192.168.144.10"

		# configure a few VirtualBox settings
		config.vm.provider "virtualbox" do |vb|
			vb.name = 'workstead'
			vb.customize ["modifyvm", :id, "--memory", settings["memory"] ||= "2048"]
			vb.customize ["modifyvm", :id, "--cpus", settings["cpus"] ||= "1"]
			vb.customize ["modifyvm", :id, "--natdnsproxy1", "on"]
			vb.customize ["modifyvm", :id, "--natdnshostresolver1", "on"]
			vb.customize ["modifyvm", :id, "--ostype", "Ubuntu_64"]
		end

		# configure a few VMware settings
		["vmware_fusion", "vmware_workstation"].each do |vmware|
			config.vm.provider vmware do |v|
				v.vmx["displayName"] = "workstead"
				v.vmx["memsize"] = settings["memory"] ||= 2048
				v.vmx["numvcpus"] = settings["cpus"] ||= 1
				v.vmx["guestOS"] = "ubuntu-64"
			end
		end

		# standardize ports naming schema
		if (settings.has_key?("ports"))
			settings["ports"].each do |port|
				port["guest"] ||= port["to"]
				port["host"] ||= port["send"]
				port["protocol"] ||= "tcp"
			end
		else
			settings["ports"] = []
		end

		# default port forwarding
		default_ports = {
			80 => 8000,
			443 => 44300,
			3306 => 33060,
			5432 => 54320
		}

		# use default port forwarding unless overriden
		default_ports.each do |guest, host|
			unless settings["ports"].any? { |mapping| mapping["guest"] == guest }
				config.vm.network "forwarded_port", guest: guest, host: host
			end
		end

		# add custome ports from configuration
		if settings.has_key?("ports")
			settings["ports"].each do |port|
				config.vm.network "forwarded_port", guest: port["guest"], host: port["host"], protocol: port["protocol"]
			end
		end

		# run the base provisioning script
		config.vm.provision "shell" do |s|
			s.path = scriptDir + "/provision.sh"
		end

		# configure the public key for SSH access
		if settings.include? 'authorize'
			config.vm.provision "shell" do |s|
				s.inline = "echo $1 | grep -xq \"$1\" /home/vagrant/.ssh/authorized_keys || echo $1 | tee -a /home/vagrant/.ssh/authorized_keys"
				s.args = [File.read(File.expand_path(settings["authorize"]))]
			end
		end

		# copy the SSH Private Keys to the box
		if settings.include? 'keys'
			settings["keys"].each do |key|
				config.vm.provision "shell" do |s|
					s.privileged = false
					s.inline = "echo \"$1\" > /home/vagrant/.ssh/$2 && chmod 600 /home/vagrant/.ssh/$2"
					s.args = [File.read(File.expand_path(key)), key.split('/').last]
				end
			end
		end

		# register all of the configured Shared Folders
		if settings.include? 'folders'
			settings["folders"].each do |folder|
				mount_opts = folder["type"] == "nfs" ? ['actimeo=1'] : []
				config.vm.synced_folder folder["map"], folder["to"], type: folder["type"] ||= nil, mount_options: mount_opts
			end
		end

		# install all the configured Nginx Sites
		settings["sites"].each do |site|
			config.vm.provision "shell" do |s|
				if (site.has_key?("hhvm") && site["hhvm"])
					s.path = scriptDir + "/serve-hhvm.sh"
					s.args = [site["map"], site["to"], site["port"] ||= "80", site["ssl"] ||= "443"]
				else
					s.path = scriptDir + "/serve.sh"
					s.args = [site["map"], site["to"], site["port"] ||= "80", site["ssl"] ||= "443"]
				end
			end
		end

		# Configure All Of The Configured Databases
		settings["databases"].each do |db|
			config.vm.provision "shell" do |s|
				s.path = scriptDir + "/create-mysql.sh"
				s.args = [db]
			end

			config.vm.provision "shell" do |s|
				s.path = scriptDir + "/create-postgres.sh"
				s.args = [db]
			end
		end

		# configure all of the server environment variables
		if settings.has_key?("variables")
			settings["variables"].each do |var|
				config.vm.provision "shell" do |s|
					s.inline = "echo \"\nenv[$1] = '$2'\" >> /etc/php5/fpm/php-fpm.conf"
					s.args = [var["key"], var["value"]]
				end

				config.vm.provision "shell" do |s|
					s.inline = "echo \"\n#Set Workstead environment variable\nexport $1=$2\" >> /home/vagrant/.profile"
					s.args = [var["key"], var["value"]]
				end
			end

			config.vm.provision "shell" do |s|
				s.inline = "service php5-fpm restart"
			end
		end

		# update composer on every provision
		config.vm.provision "shell" do |s|
			s.inline = "/usr/local/bin/composer self-update"
		end

		# Configure Blackfire.io
		if settings.has_key?("blackfire")
			config.vm.provision "shell" do |s|
				s.path = scriptDir + "/blackfire.sh"
				s.args = [
					settings["blackfire"][0]["id"],
					settings["blackfire"][0]["token"],
					settings["blackfire"][0]["client-id"],
					settings["blackfire"][0]["client-token"]
				]
			end
		end
	end
end