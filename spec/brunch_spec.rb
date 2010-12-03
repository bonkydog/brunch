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

    it "should generate a host key installation script" do
      @brunch = Brunch.new(:host_public_key => 'PUBLIC_KEY', :host_private_key => 'PRIVATE_KEY')
      script = @brunch.make_host_key_script
      script.should == <<-EOF.strip_lines
        echo 'PUBLIC_KEY' > /etc/ssh/ssh_host_rsa_key.pub
        echo 'PRIVATE_KEY' > /etc/ssh/ssh_host_rsa_key
        /etc/init.d/ssh restart
      EOF

    end
  end

  

end