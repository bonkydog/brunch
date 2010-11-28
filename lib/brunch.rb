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

class Brunch < Fog::Model

  def root
    @@root ||= File.expand_path("..", File.dirname(__FILE__))
  end

  def initialize(*arguments)
    self.connection = Fog::AWS::Compute.new(credentials)
    super
  end

  attribute :host_public_key
  attribute :host_private_key
  attribute :server
  attribute :connection
  attribute :user_data

  def generate_host_keys
    begin
      private_key_file_name = File.join(Dir::tmpdir, "terraform_#$$_#{rand(1000)}")
      public_key_file_name = private_key_file_name + ".pub"
      system("ssh-keygen -q -t rsa -N '' -f '#{private_key_file_name}'")
      self.host_public_key = Net::SSH::KeyFactory.load_public_key(public_key_file_name)
      self.host_private_key = Net::SSH::KeyFactory.load_private_key(private_key_file_name)
    ensure
      [public_key_file_name, private_key_file_name].each { |f| File.unlink(f) if f && File.exists?(f) }
    end

    [host_public_key, host_private_key]
  end

  def host_key_installation_clause
    <<-EOF.strip_lines
      echo '#{host_public_key}' > /etc/ssh/ssh_host_rsa_key.pub
      echo '#{host_private_key}' > /etc/ssh/ssh_host_rsa_key
      /etc/init.d/ssh restart
    EOF
  end

  def image_customization_clause
    <<-EOF.strip_lines

      #########################################################
      # packages

      # enable all repositories
      sed -i 's/^#deb/deb/' /etc/apt/sources.list
      sed -i 's/universe/universe multiverse/' /etc/apt/sources.list

      # update packages
      aptitude update
      aptitude -y full-upgrade

      # install packages for system administration
      aptitude -y install \
        ruby \
        ruby1.8-dev \
        libopenssl-ruby1.8 \
        libshadow-ruby1.8 \
        libxml2-dev \
        libxslt-dev \
        rdoc1.8 \
        ri1.8 \
        irb1.8 \
        build-essential \
        wget \
        curl \
        ssl-cert \
        vim \
        less \
        git-core


      #########################################################
      # ruby gems

      wget http://production.cf.rubygems.org/rubygems/rubygems-1.3.7.tgz
      tar zxvf rubygems-1.3.7.tgz

      pushd rubygems-1.3.7
        ruby ./setup.rb
        ln -sfv /usr/bin/gem1.8 /usr/bin/gem
      popd

      rm -rf rubygems-1.3.7*

      gem update --system

      gem install --no-rdoc --no-ri bundler

      #########################################################
      # chef

      gem install --no-rdoc --no-ri chef

      #########################################################
      # finish

      sudo init 1
      touch ~ubuntu/.brunch_done
      reboot
    EOF
  end

  def generate_image_customization_script
    self.user_data = ["#! /bin/bash", host_key_installation_clause, image_customization_clause].join("\n")
  end

  def generate_image_host_key_customization_script
    self.user_data = ["#! /bin/bash", host_key_installation_clause].join("\n")
  end

  def credentials
    Fog.credentials
  end

  def provision_server(options)
    connection = Fog::AWS::Compute.new(credentials)

    server_options = {
      :image_id => 'ami-1234de7b',
      :flavor_id => 't1.micro',
      :key_name => 'bonkydog',
      :user_data => user_data
    }.merge(options)

    self.server = connection.servers.create(server_options)

    server.wait_for { ready? }

    hosts = [server.dns_name, server.ip_address].join(",")

    Net::SSH::KnownHosts.add_or_replace(hosts, host_public_key)

    server.username = 'ubuntu'
    setup_complete = server.wait_for(1200, 10) do
      begin
        result = ssh('ls ~ubuntu/.brunch_done').last
        pp result
        result.status == 0 && result.stdout.include?("brunch_done")
      rescue Exception => e
        pp e
        false
      end
    end

    raise "setup failed" unless setup_complete

    server
  end

  def create_ami
    self.server ||= connection.servers.last
    server.username = 'ubuntu'

    volume = connection.volumes.create(:availability_zone => server.availability_zone, :size => 15)
    volume.device = '/dev/sdx'
    volume.server = server

    commands = [
      'sudo bash -c "echo y | mkfs.ext3 /dev/sdx"',
      "sudo mkdir /mnt/ebs",
      "sudo mount /dev/sdx /mnt/ebs",
      "sudo rsync -a --delete -x / /mnt/ebs",
      "sudo umount /mnt/ebs",
      "sudo rmdir /mnt/ebs",
    ]

    server.ssh(commands)


    snapshot = volume.snapshots.create
    snapshot.wait_for { ready? }

    volume.server = nil
    volume.wait_for { ready? }
    volume.destroy

    original_image = connection.images.get(server.image_id)

    new_image = connection.register_image(
      "brunch-#{Time.now.strftime("%Y-%m-%d-%H-%M-%S")}-#{SecureRandom.hex[0..6]}",
      'brunch: ubuntu + ruby, gems, chef-solo & git',
      original_image.root_device_name,
      [{"DeviceName" => "/dev/sda1", "DeleteOnTermination"=>"true", "SnapshotId"=> snapshot.id, "VolumeSize"=>"15"}],
      'Architecture' => original_image.architecture,
      'KernelId' => original_image.kernel_id,
      'RamdiskId' => original_image.ramdisk_id
    )

    new_image
  end

end