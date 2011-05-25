require 'brunch'
require 'rails'

module Brunch
  class Railtie < Rails::Railtie
    rake_tasks do
      load 'tasks/brunch.rake'
    end
  end
end
