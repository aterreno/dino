require 'rubygems' unless defined? Gem
require "bundler/setup"
require "sinatra"

Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }

if RUBY_VERSION < '1.9'
  $KCODE='u'
else
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

configure do
end

configure(:development) do |c|
  require "sinatra/reloader"
  c.also_reload "lib/*.rb"
end

get '/' do  
  "Hello world, it's #{Time.now} at the server!"
end  