require 'cgi'
require 'json'
require 'pp'

require 'aws-sdk-core'

module Miam; end
require 'miam/client'
require 'miam/driver'
require 'miam/dsl'
require 'miam/dsl/context'
require 'miam/dsl/context/group'
require 'miam/dsl/context/user'
require 'miam/dsl/converter'
require 'miam/exporter'
require 'miam/version'
