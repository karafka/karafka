# frozen_string_literal: true

# Karafka should work with Rails 7.1 and Karafka console should not crash
# Additionally when we use the Kubernetes Liveness Probing, it should not activate itself as
# Karafka does not start the liveness probing until it boots and it should NOT boot in the console

require 'net/http'
require 'open3'

InvalidExitCode = Class.new(StandardError)

def system!(cmd)
  stdout, stderr, status = Open3.capture3(cmd)

  return if status.success?

  raise(
    InvalidExitCode,
    "#{stdout}\n#{stderr}"
  )
end

system! <<~CMD
  bundle exec rails new \
    --skip-javascript \
    --skip-bootsnap \
    --skip-git \
    --skip-active-storage \
    --skip-active-job \
    --skip-action-cable \
    --api \
    --skip-action-mailer \
    --skip-active-record \
    app
CMD

system!('cp Gemfile ./app/')
system!('cd app && bundle install')
system!('cd app && bundle exec karafka install')
system!('cd app && mv consumers app/')

File.open('karafka.rb', 'a') do |file|
  file.puts <<~LISTENER
    require 'karafka/instrumentation/vendors/kubernetes/liveness_listener'

    listener = ::Karafka::Instrumentation::Vendors::Kubernetes::LivenessListener.new(port: 9006)

    Karafka.monitor.subscribe(listener)
  LISTENER
end

Thread.abort_on_exception = true

thread = Thread.new do
  # Make sure Rails console can start
  timeout = 'timeout --preserve-status --verbose 10'

  system!("cd app && #{timeout} bundle exec rails console")
  system!("cd app && #{timeout} bundle exec karafka console")
end

sleep(2)

not_available = false

begin
  req = Net::HTTP::Get.new('/')
  client = Net::HTTP.new('127.0.0.1', 9006)
  client.request(req)
rescue Errno::ECONNREFUSED
  not_available = true
end

assert not_available

thread.join
