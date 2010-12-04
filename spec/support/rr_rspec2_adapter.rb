require 'rr'
#
## monkeypatch for
## https://github.com/btakita/rr/issues/#issue/45
## https://github.com/rspec/rspec-core/issuesearch?state=closed&q=have_received#issue/136
#
#
module RSpec
  module Core
    module MockFrameworkAdapter
      def have_received(method = nil)
        RR::Adapters::Rspec::InvocationMatcher.new(method)
      end
    end
  end
end