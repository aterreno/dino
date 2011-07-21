require 'rubygems' unless defined? Gem
require "bundler/setup"
require "sinatra"

if RUBY_VERSION < '1.9'
  $KCODE='u'
else
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

ENV['DINO_LOG_LEVEL'] = ENV['RACK_ENV'] || 'development'
Dir[File.dirname(__FILE__) + '*.rb'].each {|file| puts file; require file }
