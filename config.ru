if ENV['RACK_ENV'] == 'production'
  require "fileutils"
  log_file = File.join(File.dirname(__FILE__), *%w[log sinatra.log])
  FileUtils.mkdir_p(File.dirname(log_file))
  FileUtils.touch(log_file)
  log = File.new(log_file, 'a')
  $stdout.reopen(log)
  $stderr.reopen(log)
  $stdout.sync = true
  $stderr.sync = true
end

require File.join(File.dirname(__FILE__), 'app')

run Sinatra::Application