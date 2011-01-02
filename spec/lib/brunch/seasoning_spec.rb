require 'spec_helper'

describe Seasoning do

  describe "#make_host_keys" do
    it "generates a pair of ssh keys for use as a host key" do

      public_key, private_key = Seasoning.make_host_keys

      public_key.should be_a OpenSSL::PKey::RSA
      private_key.should be_a OpenSSL::PKey::RSA

    end
  end

  describe "#make_host_key_script" do

    it "generates a host key installation script" do
      script = Seasoning.make_host_key_script('PUBLIC_KEY', 'PRIVATE_KEY')
      script.should == <<-EOF.unindent
        echo 'PUBLIC_KEY' > /etc/ssh/ssh_host_rsa_key.pub
        echo 'PRIVATE_KEY' > /etc/ssh/ssh_host_rsa_key
        /etc/init.d/ssh restart
      EOF
    end

  end

  describe "#make_prototype_script" do
    it "returns the brunchify script" do
      stub(File).read(%r'scripts/brunchify.bash.erb$') { "brunchify with hosthame of '<%= @hostname %>'!" }
      Seasoning.make_prototype_script("dragon").should == "brunchify with hosthame of 'dragon'!"
    end
  end

  describe "#make_customization_script" do
    it "builds a chef customization script" do
      node = {
        "recipes" => [
          "nginx",
          "cake",
          "pie"
        ],
        "cookbook_repositories" => [
          {"name" => "main_library", "location" => "git://github.com/bonkydog/cookbooks.git", "filter" => true},
          {"name" => "site_library", "location" => "git@github.com:bonkydog/seekrit_cookbooks.git", "filter" => false},
        ]
      }

      puts Seasoning.make_customization_script(node)

    end
  end

end