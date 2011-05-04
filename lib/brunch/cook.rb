require 'rubygems'
require 'bundler'
Bundler.setup(:default, :test, :development)
require 'net/ssh'

require 'tmpdir'
require 'pp'
require 'map'
require 'thor'

class BrunchError < Exception;
end

# TODO: put fingerprint in tag, put public host key in tag, add thor command to add host keys.
#monkeypatch it onto server.

class Cook

  attr_reader :config
  attr_accessor :spatula

  def initialize(config = {})
    @config = case config
      when String
        @config_file_name = config
        ::Map.new(YAML.load(Erubis::Eruby.new(File.read(config)).evaluate))
      when Map
        config
      else
        ::Map.new(config)
    end

    @spatula = Spatula.new

  end

  def write_config(file_name = @config_file_name)
    File.open(file_name, "w") do |f|
      YAML.dump(@config, f)
    end
  end

  def build_image(role_name)
    role = config.roles[role_name]

    machine_name = "#{role_name}-prototype"
    scripts = role['node'] ? [] : [Seasoning.make_prototype_script(machine_name, role[:ruby_version] || '1.9.2', role[:gem_version] || '1.6.2' )]
    scripts << role['instance_preparation']


    server, role.host_public_key = @spatula.start_server(
      role.source_image_id,
      role.flavor_id,
      role.key_name,
      role[:availability_zone],
      scripts,
      'Name' => machine_name
    )

    raise BrunchError, "brunchification seems to have failed" unless server.done_getting_brunchified?

    if role['node']
      customize_server(server, role)
    end

    server.run(role[:image_preparation]) if role[:image_preparation]

    image = @spatula.make_image(server, role_name.to_s, role.description)
    role.product_image_id = image.id

    @spatula.terminate_server(server)

  end

  # ===== SERVERS ======================================================================================================

  def customize_server(server, role)
    server = @spatula.lookup_server(server) if server.is_a?(String)
    role = config.roles[role.to_sym] if role.is_a? String

    server.run('mkdir -p /etc/chef')
    script = Seasoning.make_customization_script(role.node)
    server.upload_file("/etc/chef/customize", script)
    server.upload_file("/etc/chef/node.json", JSON.pretty_generate(role.node))
    server.run(
      "bash /etc/chef/customize #{Seasoning.redirect_command_output_to_brunch_log}",
      "bash -l -c 'chef-solo #{Seasoning.redirect_command_output_to_brunch_log}'"
    )
  end

  def boot_server(role_name, server_name)

    role = config.roles[role_name.to_sym]

    if role.has?(:product_image_id)
      puts "booting from product image"
      server = @spatula.start_server(
        role.product_image_id,
        role.flavor_id,
        role.key_name,
        role[:availability_zone],
        [role['instance_preparation']],
        :Name => server_name
      )[0]
    else
      server, role.host_public_key = @spatula.start_server(
        role.source_image_id,
        role.flavor_id,
        role.key_name,
        role[:availability_zone],
        [
          Seasoning.make_prototype_script(role_name, role.ruby_version || '1.9.2', role.gem_version || '1.6.2' ),
          role['instance_preparation']
        ],
        :Name => server_name
      )
    end

    puts server.inspect if $DEBUG

    puts "New server running at #{server.dns_name}"
  end

end

