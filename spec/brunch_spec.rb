require 'spec_helper'
require File.expand_path("../lib/brunch", File.dirname(__FILE__))



describe Brunch do

  
  before :all do
    Fog.mock!

    @brunch = Brunch.new
  end

  describe "#make_host_keys" do
    it "should generate a pair of ssh keys for use as a host key" do

      public_key, private_key = @brunch.make_host_keys

      public_key.should be_a OpenSSL::PKey::RSA
      private_key.should be_a OpenSSL::PKey::RSA

      @brunch.host_public_key.should == public_key
      @brunch.host_private_key.should == private_key
    end
  end

  describe "#make_host_key_script" do
    before do
      @brunch = Brunch.new(:host_public_key => 'PUBLIC_KEY', :host_private_key => 'PRIVATE_KEY')
    end

    it "should generate a host key installation script" do
      @brunch = Brunch.new(:host_public_key => 'PUBLIC_KEY', :host_private_key => 'PRIVATE_KEY')
      script = @brunch.make_host_key_script
      script.should == <<-EOF.strip_lines
        echo 'PUBLIC_KEY' > /etc/ssh/ssh_host_rsa_key.pub
        echo 'PRIVATE_KEY' > /etc/ssh/ssh_host_rsa_key
        /etc/init.d/ssh restart
      EOF

    end


    context "when invoked without a host public key" do
      before do
        @brunch.host_public_key = nil
      end

      it "should raise" do
        lambda {@brunch.make_host_key_script}.should raise_error(ArgumentError, "host_public_key is required for this operation")
      end
    end

    context "when invoked without a host private key" do
      before do
        @brunch.host_private_key = nil
      end

      it "should raise" do
        lambda {@brunch.make_host_key_script}.should raise_error(ArgumentError, "host_private_key is required for this operation")
      end
    end

  end

  describe "#make_prototype_script" do
    it "should read the brunchify script" do
      stub(File).read(%r'scripts/brunchify.bash$'){"brunchify!"}
      @brunch.make_prototype_script.should == "brunchify!"
      @brunch.prototype_script.should == "brunchify!"
    end
  end

  describe "#make_prototype_server" do
    
  end

end