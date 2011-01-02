require 'rubygems'
require 'bundler'
Bundler.setup(:default, :test, :development)
require 'net/ssh'
require File.expand_path("fog_ext", File.dirname(__FILE__))
require File.expand_path("string_ext", File.dirname(__FILE__))
require File.expand_path("net_ssh_known_hosts_ext", File.dirname(__FILE__))
require 'fog'
require 'fog/core/credentials'
require 'tmpdir'
require 'uuidtools'
require 'pp'
require 'highline/import'



class BrunchError < Exception; end

class Brunch < Fog::Model

  def inspect
    if self.class.const_defined?(:DISABLE_BRUNCH_INSPECTION)
      "<Brunch!>" # disable Fog::Model inspection because it causes strange loops when attributes are mocked 
    else
      super
    end
  end

  STOCK_IMAGE_ID = 'ami-480df921' # stock Ubuntu 10.04 LTS

  def root
    @@root ||= File.expand_path("..", File.dirname(__FILE__))
  end

  def initialize(*arguments)
    self.connection = Fog::AWS::Compute.new
    self.environment = ENV["BRUNCH_ENV"] || "development"
    super
  end

  attribute :host_public_key
  attribute :host_private_key
  attribute :host_keys

  attribute :prototype_server
  attribute :server
  attribute :connection

  attribute :prototype_script
  attribute :host_key_script

  attribute :prototype_image

  attribute :environment

  def make_host_keys
    begin
      private_key_file_name = File.join(Dir::tmpdir, "terraform_#$$_#{rand(1000)}")
      public_key_file_name = private_key_file_name + ".pub"
      system("ssh-keygen -q -t rsa -N '' -f '#{private_key_file_name}'")
      self.host_public_key = Net::SSH::KeyFactory.load_public_key(public_key_file_name)
      self.host_private_key = Net::SSH::KeyFactory.load_private_key(private_key_file_name)
    ensure
      [public_key_file_name, private_key_file_name].each { |f| File.unlink(f) if f && File.exists?(f) }
    end
    puts "host_keys=#{host_keys.inspect}" if $DEBUG
    host_keys
  end

  def host_keys
    host_public_key && host_private_key ? [host_public_key, host_private_key] : nil
  end

  def make_host_key_script
    requires :host_public_key, :host_private_key

    self.host_key_script = <<-EOF.strip_lines
      echo '#{host_public_key}' > /etc/ssh/ssh_host_rsa_key.pub
      echo '#{host_private_key}' > /etc/ssh/ssh_host_rsa_key
      /etc/init.d/ssh restart
    EOF
    puts "host_key_script=#{host_key_script.inspect}" if $DEBUG
    host_key_script
  end

  def make_prototype_script
    self.prototype_script = File.read(File.join(root, "scripts/brunchify.bash"))
    puts "prototype_script=#{prototype_script.inspect}" if $DEBUG
    prototype_script
  end

  def make_prototype_server
    requires :host_key_script, :prototype_script

    self.prototype_server = start_server(STOCK_IMAGE_ID, :boot_script => prototype_script, :tags => {'prototype' => true})

    raise BrunchError, "Brunchification seems to have failed." unless prototype_server.got_brunchified?

    prototype_server
  end

  def new_prototype_image_name
    "brunch-#{Time.now.strftime("%Y-%m-%d-%H-%M-%S")}-#{SecureRandom.hex[0..6]}"
  end

  def wait_for_image_to_become_available(name)
    image = nil
    Fog.wait_for(60 * 30, 10) do
      image = connection.images.all("is-public" => false).detect do |i|
        i.location.include?(name) && i.state == 'available'
      end
    end
    image
  end

  def make_prototype_image
    requires :prototype_server

    description = 'brunch prototype: ubuntu + ruby, gems, chef-solo & git'
    name = new_prototype_image_name
    connection.create_image(prototype_server.id, name, description)

    prototype_image = wait_for_image_to_become_available(name)

    raise BrunchError, "Prototype image creation seems to have failed" unless prototype_image

    connection.create_tags(prototype_image.id, brunch_tags.merge(:prototype => true))
    #TODO: tag the snapshot!
    
    prototype_image
  end

  def find_existing_prototype_image
    my_images = connection.images.all("is-public" => false)
    brunch_images = my_images.select{|i| i.location.match(/\/brunch/)}
    self.prototype_image =  brunch_images.sort_by(&:location).last
  end

  def make_server(options = {})
    requires :host_key_script
    image_id = options[:image_id] || prototype_image.id or raise "No image specified (and couldn't find a brunch prototype image)"
    self.server = start_server(image_id)
  end

  def make_destroy_everything
    unless agree("Are you sure you want to destroy EVERYTHING?")
      puts "OK, NOT destroying everything."
      return
    end

    connection.images.all("is-public" => false).each {|image| image.deregister(true)}
    connection.snapshots.each {|snapshot| snapshot.destroy}
    connection.volumes.each {|volume| volume.destroy if volume.ready? }
    connection.servers.each do |server|
      Net::SSH::KnownHosts.remove(server.dns_name)
      server.destroy
    end
  end
  
  def destroy_everything
    nil
  end

  def brunch_tags
    {:brunch => true, :environment => environment}
  end

  # ===== UTILITIES ====================================================================================================

  def start_server(image_id , options)
    requires :host_key_script

    user_data = ["#!/bin/bash\nset -x\nset -e\n", host_key_script, options[:boot_script].to_s].join("\n")

    puts "user_data=#{user_data.inspect}" if $DEBUG

    server_options = {
      :image_id => image_id,
      :flavor_id => 't1.micro',
      :key_name => 'bonkydog',
      :user_data => user_data
    }


    new_server = connection.servers.create(server_options)

    new_server.wait_for { ready? }

    tags = brunch_tags.merge(options[:tags])
    connection.create_tags([new_server.id] + new_server.volumes.map{|v|v.id}, tags)

    hosts = [new_server.dns_name, new_server.ip_address].join(",")
    Net::SSH::KnownHosts.add_or_replace(hosts, host_public_key)

    puts "new_server=#{new_server.inspect}" if $DEBUG
    new_server
  end




end