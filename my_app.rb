require 'rubygems' unless defined? Gem
require "bundler/setup"
require "sinatra"

if RUBY_VERSION < '1.9'
  $KCODE='u'
else
  Encoding.default_external = Encoding::UTF_8
  Encoding.default_internal = Encoding::UTF_8
end

set :logging, false

ENV['DINO_LOG_LEVEL'] = ENV['RACK_ENV'] || 'development'
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }

configure do
  use Dino::Logger::Rack, ENV['RACK_BASE_URI'] || '"/"'
end

configure(:development) do |c|
  require "sinatra/reloader"
  c.also_reload "lib/*.rb"
end

get '/' do
  "Hello world, it's #{Time.now} at the server!"
end

get '/fail' do
  throw "this is intentional dude!"end