# frozen_string_literal: true

# Karafka 2.3.2+ should not work with Web UI version 0.8.2 or higher

require 'open3'

InvalidExitCode = Class.new(StandardError)

def system!(cmd, raise_error: true)
  stdout, stderr, status = Open3.capture3(cmd)

  return if status.success?

  msg = "#{stdout}\n#{stderr}"

  raise_error ? raise(InvalidExitCode, msg) : msg
end

Bundler.with_unbundled_env do
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
  msg = system!('cd app && bundle exec karafka install', raise_error: false)

  exit if msg.include?('karafka-web < 0.8.2 is not compatible with this karafka version')

  raise InvalidExitCode
end
