require 'rr'

# Requires supporting files with custom matchers and macros, etc,
# in ./support/ and its subdirectories.
Dir["#{File.dirname(__FILE__)}/support/**/*.rb"].each {|f| require f}

RSpec.configure do |c|
  c.mock_with :rr
  # c.mock_with RR::Adapters::Rspec

end

