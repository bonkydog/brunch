require File.expand_path("../lib/brunch", File.dirname(__FILE__))


describe Brunch do
  describe "#generate_host_key" do
    it "should generate a pair of ssh keys for use as a host key" do
      brunch = Brunch.new
      public_key, private_key = brunch.generate_host_keys
      public_key.should be_a OpenSSL::PKey::RSA
      private_key.should be_a OpenSSL::PKey::RSA
    end
  end

end