$LOAD_PATH.unshift File.expand_path(File.dirname(__FILE__)) + '/lib/'
require 'sfn-serverspec/version'
Gem::Specification.new do |s|
  s.name = 'sfn-serverspec'
  s.version = SfnServerspec::VERSION.version
  s.summary = 'Executes Serverspec assertions against stack compute resources'
  s.author = 'Heavy Water Operations'
  s.email = 'support@heavywater.io'
  s.homepage = 'http://github.com/sparkleformation/sfn-serverspec'
  s.description = 'Executes Serverspec assertions against stack compute resources'
  s.license = 'Apache-2.0'
  s.require_path = 'lib'
  s.add_dependency 'sfn', '>= 1.0.0', '< 2.0'
  s.add_dependency 'serverspec', '~> 2.24'
  s.files = Dir['{lib,bin,docs}/**/*'] + %w(sfn-serverspec.gemspec README.md CHANGELOG.md LICENSE)
end
