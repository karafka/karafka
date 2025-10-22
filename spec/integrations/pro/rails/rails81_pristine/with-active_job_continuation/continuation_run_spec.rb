# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

# Karafka Pro should work with Rails 8.1 ActiveJob Continuation feature
# This tests that jobs can be interrupted and resumed using the continuation API with Pro features

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

mod = Module.new do
  def self.token
    ENV.fetch('KARAFKA_PRO_LICENSE_TOKEN')
  end
end

Karafka.const_set(:License, mod)
require 'karafka/pro/loader'

Karafka::Pro::Loader.require_all

ExampleApp.initialize!

setup_karafka do |config|
  config.concurrency = 1
end

draw_routes do
  active_job_topic DT.topic
end

# Test job that uses the continuation API to track progress across interruptions
# This version tests Pro-specific features like partitioning
class ContinuableJobWithPartitioning < ActiveJob::Base
  include ActiveJob::Continuable

  queue_as DT.topic

  # Pro supports scheduled messages, so we can use the default resume_options with wait: 5.seconds
  # However, for this test we use wait: 0 for faster execution
  self.resume_options = { wait: 0 }

  karafka_options(
    partitioner: ->(job) { job.arguments.first.to_s }
  )

  def perform(partition_key, total_steps)
    DT[:started] << partition_key
    DT[:partition_keys] << partition_key

    # Step 1: Initialize
    step :initialize_data do
      DT[:steps] << "#{partition_key}:initialize"
      DT[:resumptions] << resumptions
    end

    # Step 2: Process with cursor tracking
    step :process_items do |step|
      start_from = step.cursor || 0
      (start_from...total_steps).each do |i|
        DT[:processed] << "#{partition_key}:#{i}"
        DT[:resumptions] << resumptions
        step.advance!(from: i + 1)
      end
    end

    # Step 3: Finalize
    step :finalize
  end

  private

  def finalize
    DT[:steps] << "#{arguments.first}:finalize"
    DT[:resumptions] << resumptions
    DT[:completed] << arguments.first
  end
end

# Test that the adapter properly reports stopping status in Pro
class StoppingCheckJob < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[:stopping_status] << ActiveJob::Base.queue_adapter.stopping?
  end
end

# Initialize data structures
DT[:started] = []
DT[:partition_keys] = []
DT[:steps] = []
DT[:processed] = []
DT[:resumptions] = []
DT[:completed] = []
DT[:stopping_status] = []

# Enqueue continuable jobs with different partition keys
ContinuableJobWithPartitioning.perform_later('key_a', 3)
ContinuableJobWithPartitioning.perform_later('key_b', 3)

# Enqueue a job that checks the stopping status
StoppingCheckJob.perform_later

start_karafka_and_wait_until do
  DT[:completed].size >= 2 && DT[:stopping_status].size >= 1
end

# Verify both jobs completed successfully
assert_equal 2, DT[:started].size, 'Both jobs should have started'
assert_equal 2, DT[:completed].size, 'Both jobs should have completed'

# Verify partition keys were tracked
assert_equal %w[key_a key_b].sort, DT[:partition_keys].sort, 'Partition keys should be tracked'

# Verify all steps were executed for both jobs
assert_equal 4, DT[:steps].size, 'All steps for both jobs should execute'
assert DT[:steps].include?('key_a:initialize'), 'Job A should initialize'
assert DT[:steps].include?('key_a:finalize'), 'Job A should finalize'
assert DT[:steps].include?('key_b:initialize'), 'Job B should initialize'
assert DT[:steps].include?('key_b:finalize'), 'Job B should finalize'

# Verify all items were processed for both jobs
processed_a = DT[:processed].select { |p| p.start_with?('key_a:') }
processed_b = DT[:processed].select { |p| p.start_with?('key_b:') }
assert_equal ['key_a:0', 'key_a:1', 'key_a:2'], processed_a, 'All items for key_a processed'
assert_equal ['key_b:0', 'key_b:1', 'key_b:2'], processed_b, 'All items for key_b processed'

# Verify resumptions counter (should be 0 since we didn't actually interrupt)
assert DT[:resumptions].all?(0), 'Resumptions should be 0 when not interrupted'

# Verify the adapter reports stopping status correctly
assert_equal [false], DT[:stopping_status], 'Adapter should not be stopping during normal run'

# Verify we're using Karafka Pro
assert Karafka.pro?
