require File.expand_path("../../brunch", __FILE__)
class BrunchThor < Thor

  namespace :brunch

  class_option :config_file, :type => :string, :desc => "Brunch configuration file path", :optional => true, :default => './Brunchfile'
  desc "build_image ROLE", 'build an image for a role'

  def build_image(role_name)
    brunch.build_image(role_name)
#    brunch.write_config
  end

  desc "boot_server ROLE NAME", "start a server of the given role"
  def boot_server(role, name)
    brunch.boot_server(role, name)
  end

  desc "customize_server SERVER_ID ROLE", "start a server of the given role"
  def customize_server(server_id, role_name)
    brunch.customize_server(server_id, role_name)
  end

  no_tasks do
    def brunch
      @brunch ||= Cook.new(options[:config_file])
    end
  end

end

Brunch.start if $0 == __FILE__
