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

  describe "#generate_host_key_installation_script" do

    it "should generate a host key installation script" do
      script = Brunch.new.generate_host_key_installation_script('PUBLIC_KEY', 'PRIVATE_KEY')
      script.should == <<-EOF.map{|line| line.strip}
        echo 'PUBLIC_KEY' > /etc/ssh/ssh_host_rsa_key.pub
        echo 'PRIVATE_KEY' > /etc/ssh/ssh_host_rsa_key
        rm /etc/ssh/ssh_host_dsa_key
        rm /etc/ssh/ssh_host_dsa_key.pub
        /etc/init.d/ssh reload
      EOF

    end
  end

end