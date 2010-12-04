require 'rubygems'
require 'bundler'
Bundler.setup(:default, :test, :development)
require 'net/ssh'
require File.expand_path("string_ext", File.dirname(__FILE__))
require File.expand_path("net_ssh_known_hosts_ext", File.dirname(__FILE__))
require 'fog'
require 'fog/core/credentials'
require 'tmpdir'
require 'uuidtools'
require 'pp'
require 'highline/import'

#class Fog::AWS::Compute::Server < Fog::Model
#
#  def got_brunchified?
#    wait_for(1200, 10) { brunchified? }
#  end
#
#  def brunchified?
#    return true if Fog.mocking?
#    self.username = 'ubuntu'
#    result = ssh('ls ~ubuntu/.brunch_done').last
#    result.status == 0 && result.stdout.include?("brunch_done")
#  rescue Exception => e
#    false
#  end
#end

class BrunchError < Exception; end

class Brunch < Fog::Model

  def inspect
    if self.class.const_defined?(:DISABLE_BRUNCH_INSPECTION)
      "<Brunch!>" # disable Fog::Model inspection because it causes strange loops when attributes are mocked 
    else
      super
    end
  end

  STOCK_IMAGE_ID = 'ami-1234de7b' # stock Ubuntu 10.10 LTS

  def root
    @@root ||= File.expand_path("..", File.dirname(__FILE__))
  end

  def initialize(*arguments)
    self.connection = Fog::AWS::Compute.new(Fog.credentials)
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
    pp host_keys if $DEBUG
    host_keys
  end

  def host_keys=(keys)
    host_public_key, host_private_key = keys
  end
  
  def host_keys
    [host_public_key, host_private_key]
  end

  def make_host_key_script
    requires :host_public_key, :host_private_key

    self.host_key_script = <<-EOF.strip_lines
      echo '#{host_public_key}' > /etc/ssh/ssh_host_rsa_key.pub
      echo '#{host_private_key}' > /etc/ssh/ssh_host_rsa_key
      /etc/init.d/ssh restart
    EOF
  end

  def make_prototype_script
    self.prototype_script = File.read(File.join(root, "scripts/brunchify.bash"))
  end

  def make_prototype_server
    requires :host_public_key, :host_private_key

    self.prototype_server = start_server(STOCK_IMAGE_ID, prototype_script)

    raise BrunchError, "Brunchification seems to have failed." unless prototype_server.got_brunchified?

    prototype_server
  end

#  def make_prototype_image
#    requires :prototype_server
#
#    volume = connection.volumes.create(:availability_zone => prototype_server.availability_zone, :size => 15)
#    volume.device = '/dev/sdx'
#    volume.server = prototype_server
#
#    commands = [
#      'sudo bash -c "echo y | mkfs.ext3 /dev/sdx"',
#      "sudo mkdir /mnt/ebs",
#      "sudo mount /dev/sdx /mnt/ebs",
#      "sudo rsync -a --delete -x / /mnt/ebs",
#      "sudo umount /mnt/ebs",
#      "sudo rmdir /mnt/ebs",
#    ]
#
#    prototype_server.username = 'ubuntu'
#    prototype_server.ssh(commands)
#
#    snapshot = volume.snapshots.create
#    snapshot.wait_for { ready? }
#
#    volume.server = nil
#    volume.wait_for { ready? }
#    volume.destroy
#
#    original_image = connection.images.get(prototype_server.image_id)
#
#    new_image = connection.register_image(
#      "brunch-#{Time.now.strftime("%Y-%m-%d-%H-%M-%S")}-#{SecureRandom.hex[0..6]}",
#      'brunch: ubuntu + ruby, gems, chef-solo & git',
#      original_image.root_device_name,
#      [{"DeviceName" => "/dev/sda1", "DeleteOnTermination"=>"true", "SnapshotId"=> snapshot.id, "VolumeSize"=>"15"}],
#      'Architecture' => original_image.architecture,
#      'KernelId' => original_image.kernel_id,
#      'RamdiskId' => original_image.ramdisk_id
#    )
#
#    new_image
#  end

#  def prototype_image
#    @prototype_image ||= begin
#      my_images = connection.images.all("is-public" => false)
#      brunch_images = my_images.select{|i| i.location.match(/\/brunch/)}
#      most_recent_image =  brunch_images.sort_by(&:location).last
#      most_recent_image
#    end
#  end

#  def make_server(options = {})
#    image_id = options[:image_id] || prototype_image.id or raise "No image specified (and couldn't find a brunch prototype image)"
#    self.server = start_server(image_id)
#  end

#  def make_destroy_everything
#    unless agree("Are you sure you want to destroy EVERYTHING?")
#      puts "OK, NOT destroying everything."
#      return
#    end
#
#    connection.images.all("is-public" => false).each {|image| image.deregister(true)}
#    connection.snapshots.each {|snapshot| snapshot.destroy}
#    connection.volumes.each {|volume| volume.destroy if volume.ready? }
#    connection.servers.each do |server|
#      Net::SSH::KnownHosts.remove(server.dns_name)
#      server.destroy
#    end
#  end
  
#  def destroy_everything
#    nil
#  end


  # ===== UTILITIES ====================================================================================================

#  def start_server(image_id , boot_script = nil)
#
#    user_data = ["#!/bin/bash", host_key_script, boot_script.to_s].join("\n")
#
#    server_options = {
#      :image_id => image_id,
#      :flavor_id => 't1.micro',
#      :key_name => 'bonkydog',
#      :user_data => user_data
#    }
#
#    new_server = connection.servers.create(server_options)
#
#    new_server.wait_for { ready? }
#
#    hosts = [new_server.dns_name, new_server.ip_address].join(",")
#
#    #Net::SSH::KnownHosts.add_or_replace(hosts, host_public_key)
#
#    pp new_server if $DEBUG
#    new_server
#  end




end