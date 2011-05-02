require File.expand_path("../../brunch", __FILE__)

$DEBUG = true if ENV['DEBUG_BRUNCH']

namespace :brunch do

  def brunch
    @brunch || Cook.new(ENV['BRUNCHFILE'] || File.join(Rake.application.original_dir, "Brunchfile"))
  end

  desc "build an image for a role"
  task :build_image, [:role_name] do |t, args|
    brunch.build_image(args[:role_name])
    # brunch.write_config
  end

  desc "start a server of the given role"
  task :boot_server, [:role, :name] do |t, args|
    brunch.boot_server(args[:role], args[:name])
  end

  desc "start a server of the given role"
  task :customize_server, [:server_id, :role_name] do |t, args|
    brunch.customize_server(args[:server_id], args[:role_name])
  end


end
