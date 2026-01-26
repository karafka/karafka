# frozen_string_literal: true

# Karafka 2.4.0+ should not work with Web UI version 0.9.0 lower than 0.9.0

require "open3"

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

  system!("cp Gemfile ./app/")
  system!("cd app && bundle install")
  msg = system!("cd app && bundle exec karafka install", raise_error: false)

  exit if msg.include?("karafka-web < 0.10.0 is not compatible with this karafka version")

  raise InvalidExitCode
end
