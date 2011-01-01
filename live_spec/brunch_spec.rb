require File.expand_path('../live_spec_helper', __FILE__)
require 'pp'
require 'fog'
require 'fog/core/credentials'
require 'rake'
require 'net/ssh'
require File.expand_path("../lib/fog_ext", File.dirname(__FILE__))
require File.expand_path("../lib/string_ext", File.dirname(__FILE__))
require File.expand_path("../lib/net_ssh_known_hosts_ext", File.dirname(__FILE__))



describe "Brunch rake tasks" do

  before :all do
    @ec2 = Fog::AWS::Compute.new
    ENV['BRUNCH_ENV'] = 'test'
    destroy_test_resources
  end

  before do
    @rake = Rake.application = Rake::Application.new
    @rake.options.trace = true
    load File.expand_path("../lib/tasks/brunch.rake", File.dirname(__FILE__))

  end

  after do
    Rake.application = nil
  end

  describe "brunch:prototype:image" do
    it "boots a stock server, brunchifies it, then burns an ami" do

      @rake['brunch:prototype:image'].invoke
#      system 'ruby -d bin/rake --trace brunch:prototype:image'
      
      prototype_server = @ec2.servers.detect { |x| x.tags['environment'] == 'test' && x.state != "terminated" }

      prototype_server.should_not be_nil
      prototype_server.should be_ready
      prototype_server.tags['brunch'].should == 'true'
      prototype_server.tags['prototype'].should == 'true'
      prototype_server.should be_brunchified

      my_images = @ec2.images.all("is-public" => false)

      brunch_image = my_images.detect { |i| i.tags['environment'] == 'test' && i.location.match(/\/brunch/) }
      brunch_image.should_not be_nil
    end
  end


  after :all do
    destroy_test_resources
  end


  def destroy_test_resources
    @ec2.images.all("is-public" => false).select { |x| x.tags['environment'] == 'test' }.each { |image| image.deregister(true) }
    @ec2.snapshots.select { |x| x.tags['environment'] == 'test' }.each { |snapshot| snapshot.destroy }
    @ec2.volumes.select { |x| x.tags['environment'] == 'test' }.each { |volume| volume.destroy if volume.ready? }

    @ec2.servers.select { |x| x.tags['environment'] == 'test' && x.state != "terminated" }.each do |server|
      puts "destroying #{server.dns_name}"
      Net::SSH::KnownHosts.remove(server.dns_name)
      server.destroy
    end
  end


end