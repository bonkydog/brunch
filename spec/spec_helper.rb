require 'rr'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

require 'fake_web'
FakeWeb.allow_net_connect = false

ENV['BRUNCH_ENV'] = 'test'

#require 'fog'
#Fog.mock!

RSpec.configure do |c|
  c.mock_with :rr
  # c.mock_with RR::Adapters::Rspec

end

