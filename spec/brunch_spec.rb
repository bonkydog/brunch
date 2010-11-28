require 'spec_helper'
require File.expand_path("../lib/brunch", File.dirname(__FILE__))

describe Brunch do

  before :all do
    Fog.mock!
    @brunch = Brunch.new
  end

  describe "#generate_host_key" do
    it "should generate a pair of ssh keys for use as a host key" do


      public_key, private_key = @brunch.generate_host_keys

      public_key.should be_a OpenSSL::PKey::RSA
      private_key.should be_a OpenSSL::PKey::RSA

      @brunch.host_public_key.should == public_key
      @brunch.host_private_key.should == private_key
    end
  end

  describe "#generate_host_key_installation_script" do

    it "should generate a host key installation script" do
      @brunch = Brunch.new(:host_public_key => 'PUBLIC_KEY', :host_private_key => 'PRIVATE_KEY')
      script = @brunch.generate_image_customization_script()
      script.should == <<-EOF.strip_lines
        #! /bin/bash
        echo 'PUBLIC_KEY' > /etc/ssh/ssh_host_rsa_key.pub
        echo 'PRIVATE_KEY' > /etc/ssh/ssh_host_rsa_key
        /etc/init.d/ssh restart
      EOF

    end
  end

  describe "#provision_server" do
    
    it "should call a bunch of fog stuff to set up a server" do
      fake_public_host_key = 'FAKE PUBLIC HOST KEY'
      stub(@brunch).host_public_key { fake_public_host_key}

      fake_credentials = {
        :private_key_path=>"~/.ssh/amazon_id_rsa",
        :aws_secret_access_key=>"MC_LOGOS",
        :aws_access_key_id=>"BOGUS"}

      connection = stub!

      stub(@brunch).credentials {fake_credentials}

      expected_server_spec = {
        :image_id => 'ami-1234de7b',
        :flavor_id => 't1.micro',
        :key_name => 'bonkydog',
        :user_data => "USER DATA"
      }

      mock.proxy(Fog::AWS::Compute).new(fake_credentials) do |connection|
        mock.proxy(connection).servers do |servers|
          mock.proxy(servers).create(expected_server_spec) do |server|
            mock(server).wait_for
            mock(server).reload
            stub(server).dns_name {'www.example.com'}
            stub(server).ip_address {'127.0.0.1'}
            server
          end
        end
      end

      mock(Net::SSH::KnownHosts).add_or_replace('www.example.com,127.0.0.1', fake_public_host_key)

      @brunch.user_data = "USER DATA"
      @brunch.provision_server
    end
  end

  describe "#install_chef_on_server" do
    it "should install chef on the server"
  end

  describe "#create_ami" do
    it "should create a new ami"
  end

=begin


task :provision_server => :generate_user_data do


end

task :create_ami do
  connection = Fog::AWS::Compute.new(
    :aws_access_key_id => CONFIG.aws_access_key_id,
    :aws_secret_access_key => CONFIG.aws_secret_access_key
  )

  server = connection.servers.first # scaffolding.
  server.username = 'ubuntu'
  volume = connection.volumes.create(:availability_zone => server.availability_zone, :size => 15)
  volume.device = '/dev/sdx'
  volume.server = server

  server.ssh('sudo bash -c "echo y | mkfs.ext3 /dev/sdx"')
  server.ssh("sudo mkdir /mnt/ebs")
  server.ssh("sudo mount /dev/sdx /mnt/ebs")
  server.ssh("sudo rsync -a --delete -x / /mnt/ebs")
  server.ssh("sudo umount /mnt/ebs")

  snapshot = volume.snapshots.create

  snapshot.wait_for{ ready? }

  original_image = connection.images.detect{|i| i.id == server.image_id}

  new_image = connection.register_image(
    'terraformed',
    'terraformed image',
    original_image.root_device_name,
    [{"DeviceName" => "/dev/sda1", "DeleteOnTermination"=>"true", "SnapshotId"=> snapshot.id, "VolumeSize"=>"15"}],
    'Architecture' => original_image.architecture,
    'KernelId' => original_image.kernel_id,
    'RamdiskId' => original_image.ramdisk_id
  )


  server = connection.servers.create({
    :image_id => 'ami-4606f32f',
    :flavor_id => 't1.micro',
    :key_name => 'bonkydog',
    :user_data => CONFIG.user_data
  })

  server.wait_for { ready? }

  server.reload

  pp server

end

=end
end