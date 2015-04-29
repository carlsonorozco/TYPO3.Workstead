require 'json'
require 'yaml'

VAGRANTFILE_API_VERSION = "2"
confDir = $confDir ||= File.expand_path("~/.workstead")

worksteadYamlPath = confDir + "/Workstead.yaml"

require File.expand_path(File.dirname(__FILE__) + '/scripts/workstead.rb')

Vagrant.configure(VAGRANTFILE_API_VERSION) do |config|
	Workstead.configure(config, YAML::load(File.read(worksteadYamlPath)))
end
