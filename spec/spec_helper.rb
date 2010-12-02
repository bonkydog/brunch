require 'rr'

require 'fakeweb'

FakeWeb.allow_net_connect = false


Rspec.configure do |c|
  c.mock_with :rr
  #  c.mock_with RR::Adapters::Rspec

end


