require 'spec_helper'


describe Cook do

  before do
    @config = {
      :roles => {
        :micro_base => {
          :source_image_id => 'ami-a2f405cb',
          :flavor_id => 't1.micro',
          :key_name => 'bonkydog',
          :description => 'micro base is your friend!'
        }
      }
    }


    @brunch = Cook.new(@config)

  end


  describe "#build_image" do

    it "should build the image and update the configuration" do

      @fake_server = Object.new
      @fake_image = stub!.id {'ami-fake'}

      @fake_spatula = Object.new

      mock(Seasoning).make_prototype_script("micro_base-prototype", '1.9.2', '1.6.2') {"boo!"}

      mock(@fake_spatula).start_server('ami-a2f405cb', 't1.micro', 'bonkydog', ['boo!'], {"Name"=>"micro_base-prototype"}) {[@fake_server, 'fake_public_key']}

      mock(@fake_server).done_getting_brunchified? { true }

      mock(@fake_spatula).make_image(@fake_server, 'micro_base', 'micro base is your friend!'){@fake_image}

      mock(@fake_spatula).terminate_server(@fake_server)

      @brunch.spatula = @fake_spatula
      @brunch.build_image(:micro_base)

      @brunch.config.roles[:micro_base].host_public_key.should == 'fake_public_key'
      @brunch.config.roles[:micro_base].product_image_id.should == 'ami-fake'

      puts YAML.dump(@brunch.config)
    end

  end


end