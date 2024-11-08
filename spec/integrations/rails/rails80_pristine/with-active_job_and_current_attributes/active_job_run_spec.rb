# frozen_string_literal: true

# Karafka should work with Rails and AJ + Current Attributes

# Load all the Railtie stuff like when `rails server`
ENV['KARAFKA_CLI'] = 'true'

Bundler.require(:default)

require 'action_controller'
require 'tempfile'
require 'active_job'
require 'active_job/karafka'

ActiveJob::Base.extend ::Karafka::ActiveJob::JobExtensions
ActiveJob::Base.queue_adapter = :karafka

require 'karafka/active_job/current_attributes'

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

class CurrentA < ActiveSupport::CurrentAttributes
  attribute :a
end

class CurrentB < ActiveSupport::CurrentAttributes
  attribute :b
end

Karafka::ActiveJob::CurrentAttributes.persist(CurrentA)
Karafka::ActiveJob::CurrentAttributes.persist(CurrentB)

draw_routes do
  active_job_topic DT.topic
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[0] << true
    DT[:a] << CurrentA.a
    DT[:b] << CurrentB.b
  end
end

CurrentA.a = 5
CurrentB.b = 10
Job.perform_later

CurrentA.a = 7
CurrentB.b = 8
Job.perform_later

start_karafka_and_wait_until do
  DT[0].size >= 2
end

assert_equal DT[:a], [5, 7]
assert_equal DT[:b], [10, 8]
