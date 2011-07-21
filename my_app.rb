require 'rubygems' unless defined? Gem
require "bundler/setup"
require "sinatra"

ENV['DINO_LOG_LEVEL'] = ENV['RACK_ENV'] || 'development'
Dir[File.dirname(__FILE__) + '/lib/*.rb'].each {|file| require file }

configure do
  set :logging, false
  logger.info  "#{__FILE__} up and running :-)"
end

configure(:development) do |c|
  logger.warn  "configuring #{__FILE__} in developent mode with sinatra/reloader"
  require "sinatra/reloader"
  c.also_reload "lib/*.rb"
end

get '/' do
  logger.debug  "get '/'"
  logger.warn  "configuring #{__FILE__} in production mode"
  "Hello world, it's #{Time.now} at the server!"
end

get 'fail' do
  throw "this is intentional dude!"
end