# frozen_string_literal: true

# Karafka should work with Rails 7 and Karafka console should not crash
# We should be able to create a small new Rails project and run the console and it should not crash

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

# Make sure Rails console can start
timeout = 'timeout --preserve-status --verbose 5'

system!("cd app && #{timeout} bundle exec rails console")
system!("cd app && #{timeout} bundle exec karafka console")
