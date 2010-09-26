require 'net/ssh'


class Brunch
  def generate_host_keys
    private_key_file_name = nil
    private_key_file_name = nil
    begin
      private_key_file_name = File.join(Dir.tmpdir, "terraform_#$$_#{rand(1000)}")
      public_key_file_name = private_key_file_name + ".pub"
      system("ssh-keygen -q -t rsa -N '' -f '#{private_key_file_name}'")
      public_key = Net::SSH::KeyFactory.load_public_key(public_key_file_name)
      private_key = Net::SSH::KeyFactory.load_private_key(private_key_file_name)
    ensure
      [public_key_file_name, private_key_file_name].each {|f| File.unlink(f) if f && File.exists?(f) }
    end

    [public_key, private_key]
  end

  def generate_host_key_installation_script(public_key, private_key)
    <<-EOF.map{|line| line.strip}
      echo '#{public_key}' > /etc/ssh/ssh_host_rsa_key.pub
      echo '#{private_key}' > /etc/ssh/ssh_host_rsa_key
      rm /etc/ssh/ssh_host_dsa_key
      rm /etc/ssh/ssh_host_dsa_key.pub
      /etc/init.d/ssh reload
    EOF
  end
end