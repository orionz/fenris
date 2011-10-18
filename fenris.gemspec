$:.unshift File.expand_path("../lib", __FILE__)
require "fenris/version"

Gem::Specification.new do |gem|
  gem.name     = "fenris"
  gem.version  = Fenris::VERSION

  gem.author   = "Orion Henry"
  gem.email    = "orion.henry@gmail.com"
  gem.homepage = "http://github.com/orionz/fenris"
  gem.summary  = "An authentication and service location service."

  gem.description = gem.summary

  gem.executables = "fenris"
  gem.files = Dir["**/*"].select { |d| d =~ %r{^(README|bin/|data/|ext/|lib/|spec/|test/)} }

  gem.add_dependency 'eventmachine', '>= 0.12.10'
  gem.add_dependency 'rest-client',  '>= 1.6.7'
  gem.add_dependency 'multi_json',   '>= 1.0.3'
end
