# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# Karafka Pro should support combining ActiveJob Continuation with custom partitioning.
# This verifies that continuation jobs with the same partition key go to the same partition.
# The test validates that custom partitioning logic is preserved across job dispatches.

# Load all the Railtie stuff like when `rails server`
ENV["KARAFKA_CLI"] = "true"

Bundler.require(:default)

require "tempfile"
require "action_controller"
require "active_job"
require "active_job/karafka"

ActiveJob::Base.extend Karafka::ActiveJob::JobExtensions
ActiveJob::Base.queue_adapter = :karafka

class ExampleApp < Rails::Application
  config.eager_load = "test"
end

dummy_boot_file = "#{Tempfile.new.path}.rb"
FileUtils.touch(dummy_boot_file)
ENV["KARAFKA_BOOT_FILE"] = dummy_boot_file

mod = Module.new do
  def self.token
    ENV.fetch("KARAFKA_PRO_LICENSE_TOKEN")
  end

  def self.version
    "1.0.0"
  end
end

Karafka.const_set(:License, mod)
require "karafka/pro/loader"

Karafka::Pro::Loader.require_all

ExampleApp.initialize!

setup_karafka do |config|
  config.concurrency = 5
end

# Custom consumer to track which partition each message comes from
class TrackedActiveJobConsumer < Karafka::Pro::ActiveJob::Consumer
  def consume
    messages.each(clean: true) do |message|
      # If for any reason we've lost this partition, not worth iterating over new messages
      # as they are no longer ours
      break if revoked?

      # We cannot early stop when running virtual partitions because the intermediate state
      # would force us not to commit the offsets. This would cause extensive
      # double-processing
      break if ::Karafka::App.stopping? && !topic.virtual_partitions?

      # Track the partition for each message before processing
      with_deserialized_job(message) do |job|
        user_id = job.dig("arguments", 0)

        # Store partition info before job execution
        DT[:message_partitions] << {
          user_id: user_id,
          partition: message.metadata.partition,
          job_id: job["job_id"]
        }
      end

      consume_job(message)

      # We can always mark because of the virtual offset management that we have in VPs
      mark_as_consumed(message)
    end
  end
end

draw_routes do
  active_job_topic DT.topics[0] do
    consumer TrackedActiveJobConsumer
    config(partitions: 3)
  end
  scheduled_messages(DT.topics[1])
end

# Job that uses continuation with custom partitioning
# The partitioner ensures messages for the same user_id always go to the same partition
class ProcessUserDataJob < ActiveJob::Base
  include ActiveJob::Continuable

  queue_as DT.topics[0]

  # Use wait: 0 for synchronous execution (no continuation interruption needed)
  self.resume_options = { wait: 0 }

  karafka_options(
    scheduled_messages_topic: DT.topics[1],
    dispatch_method: :produce_sync,
    partitioner: ->(job) { job.arguments.first.to_s },
    partition_key_type: :key
  )

  def perform(user_id)
    DT[:executions] << { user_id: user_id, step: "start" }

    step :process do
      DT[:executions] << { user_id: user_id, step: "process" }
    end

    step :finalize do
      DT[:executions] << { user_id: user_id, step: "finalize" }
      DT[:completed] << user_id
    end
  end
end

DT[:message_partitions] = []
DT[:executions] = []
DT[:completed] = []

# Enqueue multiple jobs for different users to test partitioning
# Each user's messages should go to a consistent partition
3.times { ProcessUserDataJob.perform_later("user_1") }
3.times { ProcessUserDataJob.perform_later("user_2") }
3.times { ProcessUserDataJob.perform_later("user_3") }

start_karafka_and_wait_until do
  DT[:completed].size >= 9
end

# Verify partitioning consistency for each user
user1_partitions = DT[:message_partitions]
  .select { |p| p[:user_id] == "user_1" }
  .map { |p| p[:partition] }

user2_partitions = DT[:message_partitions]
  .select { |p| p[:user_id] == "user_2" }
  .map { |p| p[:partition] }

user3_partitions = DT[:message_partitions]
  .select { |p| p[:user_id] == "user_3" }
  .map { |p| p[:partition] }

# Each user's jobs should all go to the same partition (partitioner ensures this)
assert_equal 1, user1_partitions.uniq.size, "All user_1 jobs should go to the same partition"
assert_equal 1, user2_partitions.uniq.size, "All user_2 jobs should go to the same partition"
assert_equal 1, user3_partitions.uniq.size, "All user_3 jobs should go to the same partition"

# Each user should have 3 jobs dispatched
assert_equal 3, user1_partitions.size, "user_1 should have 3 job messages"
assert_equal 3, user2_partitions.size, "user_2 should have 3 job messages"
assert_equal 3, user3_partitions.size, "user_3 should have 3 job messages"

# Verify all jobs executed (3 steps per job * 3 jobs per user = 9 executions per user)
user1_exec_count = DT[:executions].count { |e| e[:user_id] == "user_1" }
user2_exec_count = DT[:executions].count { |e| e[:user_id] == "user_2" }
user3_exec_count = DT[:executions].count { |e| e[:user_id] == "user_3" }

assert_equal 9, user1_exec_count, "user_1 should execute 9 total steps"
assert_equal 9, user2_exec_count, "user_2 should execute 9 total steps"
assert_equal 9, user3_exec_count, "user_3 should execute 9 total steps"

# Verify all 9 jobs (3 per user) completed
assert_equal 9, DT[:completed].size, "9 jobs should complete"
assert_equal 3, DT[:completed].count("user_1"), "3 user_1 jobs should complete"
assert_equal 3, DT[:completed].count("user_2"), "3 user_2 jobs should complete"
assert_equal 3, DT[:completed].count("user_3"), "3 user_3 jobs should complete"

# Verify we're using Karafka Pro
assert Karafka.pro?
