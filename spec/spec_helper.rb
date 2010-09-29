require 'rr'

Rspec.configure do |c|
  c.mock_with :rr
  #  c.mock_with RR::Adapters::Rspec

end


