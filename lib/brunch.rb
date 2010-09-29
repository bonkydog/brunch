require 'net/ssh'
require File.expand_path("net_ssh_known_hosts_ext", File.dirname(__FILE__))
require 'fog'
require 'fog/credentials'

class Brunch < Fog::Model

  def root
    @@root ||= File.expand_path("..", File.dirname(__FILE__))
  end

  def initialize
    @connection = Fog::AWS::Compute.new(credentials)
  end

  attribute :host_public_key
  attribute :host_private_key
  attribute :server
  attribute :connection

  def generate_host_keys
    private_key_file_name = nil
    private_key_file_name = nil
    begin
      private_key_file_name = File.join(Dir.tmpdir, "terraform_#$$_#{rand(1000)}")
      public_key_file_name = private_key_file_name + ".pub"
      system("ssh-keygen -q -t rsa -N '' -f '#{private_key_file_name}'")
      @host_public_key = Net::SSH::KeyFactory.load_public_key(public_key_file_name)
      @host_private_key = Net::SSH::KeyFactory.load_private_key(private_key_file_name)
    ensure
      [public_key_file_name, private_key_file_name].each {|f| File.unlink(f) if f && File.exists?(f) }
    end

    [@host_public_key, @host_private_key]
  end

  def generate_host_key_installation_script
    @user_data = <<-EOF
      echo '#{@host_public_key}' > /etc/ssh/ssh_host_rsa_key.pub
      echo '#{@host_private_key}' > /etc/ssh/ssh_host_rsa_key
      rm /etc/ssh/ssh_host_dsa_key
      rm /etc/ssh/ssh_host_dsa_key.pub
      /etc/init.d/ssh reload
    EOF
  end

  def credentials
    Fog.credentials
  end

  def provision_server
    require 'ruby-debug'; debugger
    @connection = Fog::AWS::Compute.new(credentials)

    @server = @connection.servers.create({
      :image_id => 'ami-1234de7b',
      :flavor_id => 't1.micro',
      :key_name => 'bonkydog',
      :user_data => @user_data
    })

    server.wait_for { ready? }
    server.reload

    hosts = [server.dns_name, server.ip_address].join(",")

    Net::SSH::KnownHosts.add_or_replace(hosts, host_public_key)

    server
  end

  def install_chef
    @server ||= connection.servers.first
    chef_install_script = File.read(File.join(root, 'scripts/install_chef.bash'))
    server.ssh(chef_install_script)
  end

  def create_ami
    @server ||= connection.servers.first
    @server.username = 'ubuntu'

    volume = @connection.volumes.create(:availability_zone => @server.availability_zone, :size => 15)
    volume.device = '/dev/sdx'
    volume.server = @server

    @server.ssh([
      'sudo bash -c "echo y | mkfs.ext3 /dev/sdx"',
      "sudo mkdir /mnt/ebs",
      "sudo mount /dev/sdx /mnt/ebs",
      "sudo rsync -a --delete -x / /mnt/ebs",
      "sudo umount /mnt/ebs",
      "sudo rmdir /mnt/ebs",
    ])

    snapshot = volume.snapshots.create

    snapshot.wait_for{ ready? }

    original_image = @connection.images.all(@server.image_id)

    @new_image = @connection.register_image(
      'terraformed',
      'terraformed image',
      original_image.root_device_name,
      [{"DeviceName" => "/dev/sda1", "DeleteOnTermination"=>"true", "SnapshotId"=> snapshot.id, "VolumeSize"=>"15"}],
      'Architecture' => original_image.architecture,
      'KernelId' => original_image.kernel_id,
      'RamdiskId' => original_image.ramdisk_id
    )

    @new_image
  end
  
end