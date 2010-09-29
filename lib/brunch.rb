require 'net/ssh'
require 'net_ssh_known_hosts_ext'
require 'fog'
require 'fog/credentials'



class Brunch < Fog::Model

  attribute :host_public_key
  attribute :host_private_key

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
    <<-EOF.map{|line| line.strip}
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
    connection = Fog::AWS::Compute.new(credentials)

    server = connection.servers.create({
      :image_id => 'ami-1234de7b',
      :flavor_id => 't1.micro',
      :key_name => 'bonkydog',
      :user_data => "USER DATA"
    })

    server.wait_for { ready? }
    server.reload

    hosts = [server.dns_name, server.ip_address].join(",")

    Net::SSH::KnownHosts.add_or_replace(hosts, host_public_key)

    server

  end
end