# frozen_string_literal: true

# Karafka should work with Rails and AJ + #perform_all_later

# Load all the Railtie stuff like when `rails server`
ENV['KARAFKA_CLI'] = 'true'

Bundler.require(:default)

require 'tempfile'
require 'action_controller'
require 'active_job'
require 'active_job/karafka'

assert_equal(
  ActiveJob::QueueAdapters::AbstractAdapter,
  ActiveJob::QueueAdapters::KarafkaAdapter.superclass
)

ActiveJob::Base.extend Karafka::ActiveJob::JobExtensions
ActiveJob::Base.queue_adapter = :karafka

class ExampleApp < Rails::Application
  config.eager_load = 'test'
end

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV['KARAFKA_BOOT_FILE'] = dummy_boot_file

ExampleApp.initialize!

setup_karafka do |config|
  config.concurrency = 1
end

draw_routes do
  active_job_topic DT.topic
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[0] << true
  end
end

ActiveJob.perform_all_later(
  Array.new(5) { Job.new }
)

start_karafka_and_wait_until do
  DT[0].size >= 5
end
