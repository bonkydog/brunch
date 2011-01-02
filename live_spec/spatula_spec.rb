require File.expand_path("../live_spec_helper", __FILE__)
require 'pp'

require 'fog'
require 'fog/core/credentials'

require 'net/ssh'

$DEBUG=true

describe Spatula do

  before(:all) { destroy_test_resources }
  after(:all)  { destroy_test_resources }

  before {@spatula = Spatula.new}

  def ec2
    @@ec2 ||= Fog::AWS::Compute.new
  end

  describe "#start_server & #make_image" do
    it "boots a server and creates an image from it" do

      image_id = 'ami-480df921'
      flavor_id = 't1.micro'
      key_name = 'bonkydog'

      custom_script = 'cp ~ubuntu/.ssh/* ~root/.ssh; touch ~root/.brunch_done'

      server, host_public_key = @spatula.start_server(image_id, flavor_id, key_name, custom_script, {:test_tag => "present"})

      host_public_key.should_not be_nil

      server.should be_ready

      server.should be_done_getting_brunchified

      server.image_id.should == image_id
      server.flavor_id.should == flavor_id
      server.key_name.should == key_name

      server.tags['brunch'].should == 'true'
      server.tags['environment'].should == 'test'
      server.tags['test_tag'].should == 'present'

      image = @spatula.make_image(server, 'test name', 'test description', {:test_tag => "also present"})
      image.state.should == 'available'

      image.name.should == 'test name'
      image.description.should == 'test description'

      image.tags['brunch'].should == 'true'
      image.tags['environment'].should == 'test'
      image.tags['test_tag'].should == 'also present'

      snapshot_id = image.block_device_mapping.first
      snapshot = ec2.snapshots.get(snapshot_id)
      snapshot.tags['brunch'].should == 'true'
      snapshot.tags['environment'].should == 'test'
      snapshot.tags['device_name'].should == '/dev/sda1'
      snapshot.tags['test_tag'].should == 'also present'
    end

end

def destroy_test_resources
  ec2.images.all("is-public" => false).select { |x| x.tags['environment'] == 'test' }.each { |image| image.deregister(true) }
  ec2.snapshots.select { |x| x.tags['environment'] == 'test' }.each { |snapshot| snapshot.destroy }
  ec2.volumes.select { |x| x.tags['environment'] == 'test' }.each { |volume| volume.destroy if volume.ready? }

  ec2.servers.select { |x| x.tags['environment'] == 'test' && x.state != "terminated" }.each do |server|
    puts "destroying #{server.dns_name}"
    Net::SSH::KnownHosts.remove(server.dns_name)
    server.destroy
  end
end


end