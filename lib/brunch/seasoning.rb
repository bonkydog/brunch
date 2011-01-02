require 'net/ssh'
require 'erubis'
require 'json'

module Seasoning
  class << self

  def root
    @@root ||= File.expand_path("..", File.dirname(__FILE__))
  end

  def make_host_keys

    host_public_key = nil
    host_private_key = nil
    begin
      private_key_file_name = File.join(Dir::tmpdir, "terraform_#$$_#{rand(1000)}")
      public_key_file_name = private_key_file_name + ".pub"
      system("ssh-keygen -q -t rsa -N '' -f '#{private_key_file_name}'")
      host_public_key = Net::SSH::KeyFactory.load_public_key(public_key_file_name)
      host_private_key = Net::SSH::KeyFactory.load_private_key(private_key_file_name)
    ensure
      [public_key_file_name, private_key_file_name].each { |f| File.unlink(f) if f && File.exists?(f) }
    end
    puts "host_public_key=#{host_public_key.inspect}" if $DEBUG
    puts "host_private_key=#{host_private_key.inspect}" if $DEBUG
    [host_public_key, host_private_key]
  end

  def make_host_key_script(host_public_key, host_private_key)
    host_key_script = <<-EOF.strip_lines
      echo '#{host_public_key}' > /etc/ssh/ssh_host_rsa_key.pub
      echo '#{host_private_key}' > /etc/ssh/ssh_host_rsa_key
      /etc/init.d/ssh restart
    EOF
    puts "host_key_script=#{host_key_script.inspect}" if $DEBUG
    host_key_script
  end

  def make_prototype_script(hostname)
    hostname = hostname.gsub(/[\s_]/, "-")
    context = {:hostname => hostname}
    template = File.read(File.expand_path("../scripts/brunchify.bash.erb", __FILE__))
    prototype_script = Erubis::Eruby.new(template).evaluate(context)

    puts "prototype_script=#{prototype_script.inspect}" if $DEBUG
    prototype_script
  end

  def make_customization_script(node)

    cookbooks = node['recipes'].map { |recipe| recipe.gsub(/::.*/, '') }.uniq
    context = {
      :node_json => node.to_json,
      :cookbooks_actually_used => cookbooks,
      :cookbook_repositories => node["cookbook_repositories"]
    }

    template = File.read(File.expand_path("../scripts/customize.bash.erb", __FILE__))
    customization_script = Erubis::Eruby.new(template).evaluate(context)

    puts "customization_script=#{customization_script.inspect}" if $DEBUG
    customization_script
  end
  end  
end
