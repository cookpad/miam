# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'miam/version'

Gem::Specification.new do |spec|
  spec.name          = 'miam'
  spec.version       = Miam::VERSION
  spec.authors       = ['Genki Sugawara']
  spec.email         = ['sgwr_dts@yahoo.co.jp']
  spec.summary       = %q{TODO: Write a short summary. Required.}
  spec.description   = %q{TODO: Write a longer description. Optional.}
  spec.summary       = %q{Miam is a tool to manage IAM.}
  spec.description   = %q{Miam is a tool to manage IAM. It defines the state of IAM using DSL, and updates IAM according to DSL.}
  spec.homepage      = 'https://github.com/winebarrel/miam'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk-core', '~> 2.0.3'
  spec.add_dependency 'ruby-progressbar'
  spec.add_dependency 'term-ansicolor'
  spec.add_development_dependency 'bundler', '~> 1.7'
  spec.add_development_dependency 'rake', '~> 10.0'
end
