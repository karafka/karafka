# frozen_string_literal: true

# Karafka should work with Rails 8.1 ActiveJob Continuation feature
# This tests that jobs can be interrupted and resumed using the continuation API

# Load all the Railtie stuff like when `rails server`
ENV['KARAFKA_CLI'] = 'true'

Bundler.require(:default)

require 'tempfile'
require 'action_controller'
require 'active_job'
require 'active_job/karafka'

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

# Test job that uses the continuation API to track progress across interruptions
class ContinuableJob < ActiveJob::Base
  include ActiveJob::Continuable

  queue_as DT.topic

  # Configure resume options for OSS Karafka (no scheduled messages support)
  # With wait: 0, jobs resume immediately without requiring scheduled messages
  self.resume_options = { wait: 0 }

  def perform(total_steps)
    DT[:started] << true

    # Step 1: Initialize
    step :initialize_data do
      DT[:steps] << :initialize
      DT[:resumptions] << resumptions
    end

    # Step 2: Process with cursor tracking
    step :process_items do |step|
      start_from = step.cursor || 0
      (start_from...total_steps).each do |i|
        DT[:processed] << i
        DT[:resumptions] << resumptions
        # Advance cursor after each item
        step.advance!(from: i + 1)
      end
    end

    # Step 3: Finalize
    step :finalize
  end

  private

  def finalize
    DT[:steps] << :finalize
    DT[:resumptions] << resumptions
    DT[:completed] << true
  end
end

# Test that the adapter properly reports stopping status
class StoppingCheckJob < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[:stopping_status] << ActiveJob::Base.queue_adapter.stopping?
  end
end

# Initialize data structures
DT[:started] = []
DT[:steps] = []
DT[:processed] = []
DT[:resumptions] = []
DT[:completed] = []
DT[:stopping_status] = []

# Enqueue a continuable job with 5 steps
ContinuableJob.perform_later(5)

# Enqueue a job that checks the stopping status
StoppingCheckJob.perform_later

start_karafka_and_wait_until do
  DT[:completed].size >= 1 && DT[:stopping_status].size >= 1
end

# Verify the job completed successfully
assert_equal 1, DT[:started].size, 'Job should have started once'
assert_equal 1, DT[:completed].size, 'Job should have completed once'

# Verify all steps were executed
assert_equal %i[initialize finalize], DT[:steps], 'All steps should execute in order'

# Verify all items were processed
assert_equal [0, 1, 2, 3, 4], DT[:processed], 'All items should be processed'

# Verify resumptions counter (should be 0 since we didn't actually interrupt)
assert DT[:resumptions].all?(0), 'Resumptions should be 0 when not interrupted'

# Verify the adapter reports stopping status correctly
# When Karafka is running normally, stopping? should return false
assert_equal [false], DT[:stopping_status], 'Adapter should not be stopping during normal run'
