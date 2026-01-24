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

# Karafka Pro should work with Rails 8.1 ActiveJob Continuation feature with scheduled resumes
# This tests that continuable jobs can use delayed resumes via Scheduled Messages

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
  active_job_topic DT.topics[0]
  scheduled_messages(DT.topics[1])
end

# Test job that uses continuation with delayed resumes (Pro feature)
class ContinuableJobWithDelayedResume < ActiveJob::Base
  include ActiveJob::Continuable

  queue_as DT.topics[0]

  # Use short wait time for testing (2 seconds instead of default 5)
  # This will cause the job to be scheduled via scheduled messages when interrupted
  self.resume_options = { wait: 2.seconds }

  # Configure to use scheduled messages for delayed dispatch
  karafka_options(
    dispatch_method: :produce_sync,
    scheduled_messages_topic: DT.topics[1]
  )

  def perform
    DT[:started] << Time.now.to_f
    DT[:resumptions] << resumptions

    step :process do
      DT[:processed] << Time.now.to_f
    end

    DT[:completed] << Time.now.to_f
  end
end

# Initialize data structures
DT[:started] = []
DT[:processed] = []
DT[:completed] = []
DT[:resumptions] = []

# Enqueue a continuable job that uses delayed resume
ContinuableJobWithDelayedResume.perform_later

start_karafka_and_wait_until do
  DT[:completed].size >= 1
end

# Verify the job completed
assert_equal 1, DT[:started].size, 'Job should have started'
assert_equal 1, DT[:completed].size, 'Job should have completed'
assert_equal 1, DT[:processed].size, 'Job should have processed'

# Verify resumptions counter
assert_equal [0], DT[:resumptions], 'Should start with 0 resumptions'

# Verify we're using Karafka Pro
assert Karafka.pro?
