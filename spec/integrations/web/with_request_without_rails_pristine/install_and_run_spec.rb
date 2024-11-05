# frozen_string_literal: true

# Karafka 2.4+ should work ok with 0.9.0+

require 'open3'
require 'net/http'
require 'webrick'

InvalidExitCode = Class.new(StandardError)
InvalidState = Class.new(StandardError)

def system!(cmd, raise_error: true)
  stdout, stderr, status = Open3.capture3(cmd)

  return if status.success?

  msg = "#{stdout}\n#{stderr}"

  raise_error ? raise(InvalidExitCode, msg) : msg
end

Bundler.with_unbundled_env do
  system!('mkdir ./app')
  system!('cp Gemfile ./app/')
  system!('cp config.ru ./app/')
  system!('cd app && bundle install')
  system!('cd app && bundle exec karafka install')
  system!('cd app && bundle exec karafka-web install')
end

Thread.abort_on_exception = true

thread = Thread.new do
  # Make sure Rails console can start
  timeout = 'timeout --verbose -s KILL 10'

  system!("cd app && #{timeout} bundle exec rackup -p 9012 || true")
end

sleep(2)

req = Net::HTTP::Get.new('/routing')
client = Net::HTTP.new('127.0.0.1', 9012)
response = client.request(req).code

thread.join

assert response == '200', response
