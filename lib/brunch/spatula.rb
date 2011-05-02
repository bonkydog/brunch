require 'fog'
require 'fog/core/credentials'
require File.expand_path("../seasoning", __FILE__)

class Spatula

  attr_reader :connection

  def initialize
    Fog.credential = ENV['FOG_CREDENTIAL'] ? ENV['FOG_CREDENTIAL'].to_sym : :default
    @connection = Fog::Compute.new(:provider => 'AWS')
  end

  def lookup_server(server_id)
    server_id = connection.servers.get(server_id)
    raise "server #{server_id} not found" unless server_id
    raise "server #{server_id} not ready" unless server_id.ready?
  end

  def start_server(image_id, flavor_id, key_name, scripts=[], tags={})

    host_public_key, host_private_key = Seasoning.make_host_keys

    user_data = <<-BASH.unindent
      #!/bin/bash
      set -x
      set -e

      #{Seasoning.redirect_script_output_to_brunch_log}

    BASH

    user_data += Seasoning.make_host_key_script(host_public_key, host_private_key)
    scripts = case scripts
      when Array then
        scripts.join('\n')
      when String then
        scripts
      else
        raise ArgumentError
     end

    user_data += scripts

    server_options = {
      :image_id => image_id,
      :flavor_id => flavor_id,
      :key_name => key_name,
      :user_data => user_data,
    }

    puts "user_data=#{user_data}" if $DEBUG

    server = connection.servers.create(server_options)

    server.wait_for { ready? }

    if ENV['DEBUG_BRUNCH']
      puts "ssh ubuntu@#{server.dns_name} tail -f /var/log/user-data.log"
      begin
        require 'appscript'
        terminal = Appscript.app("Terminal")
        terminal.do_script("until ssh ubuntu@#{server.dns_name} tail -f /var/log/brunch.log;do sleep 1; echo 'reconnecting...'; done")
      rescue LoadError
      end
    end

    tags = brunch_tags.merge(tags)
    connection.create_tags([server.id] + server.volumes.map { |v| v.id }, tags)
    server.reload

    hosts = [server.dns_name, server.public_ip_address].join(",")
    Net::SSH::KnownHosts.add_or_replace(hosts, host_public_key)

    puts "new_server=#{server.inspect}" if $DEBUG

    return server, host_public_key
  end

  def terminate_server(server)
    server.destroy
    hosts = [server.dns_name, server.public_ip_address].join(",")
    Net::SSH::KnownHosts.remove(hosts)
  end

  def make_image(server, name, description, tags={})

    connection.create_image(server.id, name, description) # does not return the image

    image = wait_for_image_to_become_available(name)
    raise BrunchError, "Prototype image creation seems to have failed" unless image

    connection.create_tags(image.id, brunch_tags.merge(tags))
    image.reload

    image.block_device_mapping.each do |device|
      snapshot = connection.snapshots.get(device['snapshotId'])
      connection.create_tags(snapshot.id, brunch_tags.merge(tags).merge("device_name" => device['deviceName']))
    end

    image
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



  def brunch_tags
    {:brunch => true, :environment => environment}
  end

  def environment
    ENV["BRUNCH_ENV"] || "development"
  end

end
