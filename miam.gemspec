# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'miam/version'

Gem::Specification.new do |spec|
  spec.name          = 'miam'
  spec.version       = Miam::VERSION
  spec.authors       = ['Genki Sugawara']
  spec.email         = ['sgwr_dts@yahoo.co.jp']
  spec.summary       = %q{Miam is a tool to manage IAM.}
  spec.description   = %q{Miam is a tool to manage IAM. It defines the state of IAM using DSL, and updates IAM according to DSL.}
  spec.homepage      = 'https://github.com/codenize-tools/miam'
  spec.license       = 'MIT'

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_dependency 'aws-sdk-iam', '~> 1'
  spec.add_dependency 'ruby-progressbar'
  spec.add_dependency 'parallel'
  spec.add_dependency 'term-ansicolor'
  spec.add_dependency 'diffy'
  spec.add_dependency 'hashie'
  spec.add_development_dependency 'bundler'
  spec.add_development_dependency 'rake'
  spec.add_development_dependency 'rspec', '>= 3.0.0'
  spec.add_development_dependency 'rspec-instafail'
  spec.add_development_dependency 'coveralls'
  spec.add_development_dependency 'nokogiri'
end
