require File.expand_path("../brunch", File.dirname(__FILE__))
require 'pp'

brunch = Brunch.new

namespace :host_key do

  task :generate do
    brunch.generate_host_keys
  end

  task :image_customization_script => :generate do
    brunch.generate_image_customization_script
  end

  task :image_host_key_customization_script => :generate do
    brunch.generate_image_host_key_customization_script
  end

end

namespace :server do

  task :provision_and_customize, [:image_id] => 'host_key:image_customization_script' do |task, options|
    brunch.provision_server(options)
  end

  task :provision, [:image_id] => 'host_key:image_host_key_customization_script' do |task, options|
    brunch.provision_server(options)
  end

  task :create_ami => :provision_and_customize do
    pp brunch.create_ami
  end

end

