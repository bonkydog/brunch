# -*- encoding: utf-8 -*-
$:.push File.expand_path("../lib", __FILE__)
require "brunch/version"

Gem::Specification.new do |s|
  s.name        = "brunch"
  s.version     = Brunch::VERSION
  s.platform    = Gem::Platform::RUBY
  s.authors     = ["Brian Jenkins"]
  s.email       = ["brian@brianjenkins.org"]
  s.homepage    = ""
  s.summary     = %q{Brunch: an operations automator}
  s.description = %q{Brunch helps you build clusters on EC2 using Fog and Chef Solo.}

  s.rubyforge_project = "brunch"

  s.files         = `git ls-files`.split("\n")
  s.test_files    = `git ls-files -- {test,spec,live_spec,features}/*`.split("\n")
  s.executables   = `git ls-files -- bin/*`.split("\n").map{ |f| File.basename(f) }
  s.require_paths = ["lib", "tasks"]

  s.add_dependency('fog', '~> 0.7.2')
  s.add_dependency('net-ssh', '~> 2.1.4')
  s.add_dependency('rake', '~> 0.8.7')
  s.add_dependency('erubis', '~> 2.7.0')
  s.add_dependency('map', '~> 3.0.0')

  s.add_development_dependency('rspec', "~>2.5.0")
  s.add_development_dependency('rr', "~>1.0.2")
  s.add_development_dependency('fakeweb', "~>1.3.0")
  s.add_development_dependency('rcov', "~>0.9.9")

end
