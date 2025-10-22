# frozen_string_literal: true

# Karafka should work with Rails 8.1 and Karafka console should not crash when we put karafka setup
# in the initializers and skip the boot file

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

initializer = './app/config/initializers/karafka.rb'
FileUtils.mv('./app/karafka.rb', initializer)

content = File.read(initializer)
content = "Rails.configuration.after_initialize do\n#{content.chomp}\nend\n"
File.write(initializer, content)

ENV['KARAFKA_BOOT_FILE'] = 'false'

timeout = 'timeout --preserve-status --verbose 10'

system!("cd app && export KARAFKA_BOOT_FILE=false && #{timeout} bundle exec rails console")
system!("cd app && export KARAFKA_BOOT_FILE=false && #{timeout} bundle exec karafka console")
