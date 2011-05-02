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
      stub(File).read(%r'scripts/brunchify.bash.erb$') {
        "brunchify with hostname='<%= @hostname %>' ruby=<%= @ruby_version %> gem=<%= @gem_version %>"
      }

      Seasoning.make_prototype_script("dragon", "1.9.2", "1.6.2").should == "brunchify with hostname='dragon' ruby=1.9.2 gem=1.6.2"
    end
  end

  describe "#make_customization_script" do
    it "builds a chef customization script" do
      node = {
        "recipes" => [
          "nginx",
          "cake",
          "pie",
          "postgresql::client",
          "postgresql::server::monster"
        ],
        "cookbook_repositories" => [
          {"name" => "main_library", "location" => "git://github.com/bonkydog/cookbooks.git", "filter" => true},
          {"name" => "site_library", "location" => "git@github.com:bonkydog/seekrit_cookbooks.git", "filter" => false},
        ]
      }

      # note that postgresql appears only once and without ::client etc.
      Seasoning.make_customization_script(node).should == <<-BASH.unindent
        mkdir -p /etc/chef/cookbooks
        
        cat <<RUBY > /etc/chef/solo.rb
        cookbook_path %w[/etc/chef/cookbooks /etc/chef/site_library]
        json_attribs  "/etc/chef/node.json"
        RUBY

        rm -rf /etc/chef/main_library
        git clone git://github.com/bonkydog/cookbooks.git /etc/chef/main_library
        if [ -f /etc/chef/main_library/.gitmodules ]; then
          cd /etc/chef/main_library
          git submodule init
          git submodule update
        fi

        rm -rf /etc/chef/site_library
        git clone git@github.com:bonkydog/seekrit_cookbooks.git /etc/chef/site_library
        if [ -f /etc/chef/site_library/.gitmodules ]; then
          cd /etc/chef/site_library
          git submodule init
          git submodule update
        fi


        for library in main_library site_library; do
          for cookbook in nginx cake pie postgresql; do
            if [ -d /etc/chef/$library/$cookbook ]; then
             ln -s /etc/chef/$library/$cookbook /etc/chef/cookbooks/$cookbook
            fi
          done
        done
      BASH

    end
  end

end