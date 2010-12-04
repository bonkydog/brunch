require 'spec_helper'
require File.expand_path("../lib/brunch", File.dirname(__FILE__))

describe Brunch do
  include BrunchMacros
  
  before :all do
    Fog.mock!
    Brunch::DISABLE_BRUNCH_INSPECTION = true
   end

  subject { Brunch.new }
  alias_method :brunch, :subject
  

  describe "#make_host_keys" do
    it "generates a pair of ssh keys for use as a host key" do

      public_key, private_key = brunch.make_host_keys

      public_key.should be_a OpenSSL::PKey::RSA
      private_key.should be_a OpenSSL::PKey::RSA

      brunch.host_public_key.should == public_key
      brunch.host_private_key.should == private_key
    end
  end

  describe "#make_host_key_script" do
    subject { Brunch.new(:host_public_key => 'PUBLIC_KEY', :host_private_key => 'PRIVATE_KEY') }

    it_should_require(:host_private_key)
    it_should_require(:host_public_key)

    it "generates a host key installation script" do
      script = subject.make_host_key_script
      script.should == <<-EOF.strip_lines
        echo 'PUBLIC_KEY' > /etc/ssh/ssh_host_rsa_key.pub
        echo 'PRIVATE_KEY' > /etc/ssh/ssh_host_rsa_key
        /etc/init.d/ssh restart
      EOF
    end

  end

  describe "#make_prototype_script" do
    it "returns and remember the brunchify script" do
      stub(File).read(%r'scripts/brunchify.bash$') { "brunchify!" }
      brunch.make_prototype_script.should == "brunchify!"
      brunch.prototype_script.should == "brunchify!"
    end
  end

  describe "#make_prototype_server" do

     subject { Brunch.new(:host_public_key => 'PUBLIC_KEY', :host_private_key => 'PRIVATE_KEY') }

    it_should_require(:host_public_key)
    it_should_require(:host_private_key)

    describe do

      before do
        @successful = true
        stub(brunch).prototype_script { "I CAN HAS PROTOTYPE?" }
        stub(brunch).start_server(Brunch::STOCK_IMAGE_ID, "I CAN HAS PROTOTYPE?") do
          @fake_server = stub!.got_brunchified? { @successful }.subject
        end
      end

      it "starts a stock server" do
        brunch.make_prototype_server
        brunch.should have_received.start_server(Brunch::STOCK_IMAGE_ID, "I CAN HAS PROTOTYPE?")
      end

      it "returns and remember the server" do
        brunch.make_prototype_server.should == @fake_server
        brunch.prototype_server.should == @fake_server
      end

      describe "when the the chef setup doesn't finish in a reasonable amount of time" do
        it "raises an error" do
          @successful = false
          lambda { brunch.make_prototype_server }.should raise_error(BrunchError, "Brunchification seems to have failed.")
        end

      end

    end
  end

end