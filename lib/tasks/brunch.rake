require File.expand_path("../brunch", File.dirname(__FILE__))
require 'pp'

brunch = Brunch.new

namespace :host_key do

  task :generate do
    pp brunch.generate_host_keys
  end

  task :install_script => :generate do
    p brunch.generate_host_key_installation_script
  end

end

namespace :server do

  task :provision => 'host_key:install_script' do
    pp brunch.provision_server
  end

  task :install_chef do
    pp brunch.install_chef
  end

  task :create_ami do
    pp brunch.create_ami
  end


end

