require 'fog'
require 'tempfile'

class Fog::AWS::Compute::Server < Fog::Model

  def done_getting_brunchified?
    wait_for(60 * 30, 10) { brunchified? }
  end

  def brunchified?
    return true if Fog.mocking?
    result = ssh('ls ~root/.brunch_done').last
    result.status == 0 && result.stdout.include?("brunch_done")
  rescue Exception => e
    false
  end

  def run(*commands)
    requires :identity, :ip_address, :private_key, :username

    commands.each do |command|

      puts "running: #{command}"

      result = Fog::SSH.new(ip_address, username, :keys => [], :forward_agent => true).run(command).first

      puts "result: #{result.inspect}"

      raise "command failed" unless result.status == 0
    end
  end

  def upload_file(destination_path, content)
    Tempfile.with(content) do |temp_filename|
      system "scp -q #{temp_filename} #{username}@#{ip_address}:#{destination_path}"
    end
  end

end

