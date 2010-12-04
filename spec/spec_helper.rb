require 'rr'

require 'fakeweb'

FakeWeb.allow_net_connect = false

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

Rspec.configure do |c|
  c.mock_with :rr
  #  c.mock_with RR::Adapters::Rspec

end

