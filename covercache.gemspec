# encoding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'covercache/version'

Gem::Specification.new do |spec|
  spec.name          = "covercache"
  spec.version       = Covercache::VERSION
  spec.authors       = ["Tõnis Simo", "Brian Goff"]
  spec.email         = ["anton.estum@gmail.com"]
  spec.description   = %q{Helper method to simplify Rails caching, based on PackRat}
  spec.summary       = %q{Rails cache helper based on PackRat gem}
  spec.homepage      = "http://github.com/estum/covercache"
  spec.license       = "MIT"

  spec.files         = `git ls-files`.split($/)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_dependency "activesupport", '>= 3.2.0', '< 4'
  spec.add_dependency "activerecord", '>= 3.2.0', '< 4'
  
  spec.add_development_dependency "bundler", "~> 1.3"
  spec.add_development_dependency "rails", '>= 3.2.0', '< 4'
  spec.add_development_dependency "rdoc"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "rake"
  spec.add_development_dependency "sqlite3"
end