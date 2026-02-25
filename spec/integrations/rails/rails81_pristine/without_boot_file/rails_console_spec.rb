# frozen_string_literal: true

# Karafka should crash if we try to run CLI or Rails console when no boot file is defined and
# no initializer

require "net/http"
require "open3"

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

system!("cp Gemfile ./app/")
system!("cd app && bundle install")
system!("cd app && bundle exec karafka install")

FileUtils.rm("./app/karafka.rb")

timeout = "timeout --preserve-status --verbose 10"

failed1 = false
failed2 = false

begin
  system!("cd app && #{timeout} bundle exec rails console")
rescue InvalidExitCode
  failed1 = true
end

begin
  system!("cd app && #{timeout} bundle exec karafka console")
rescue InvalidExitCode
  failed2 = true
end

# Both should fail as no boot file present
raise unless failed1 && failed2
