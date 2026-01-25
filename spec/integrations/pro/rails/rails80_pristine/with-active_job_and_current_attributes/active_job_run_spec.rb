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

# Karafka should work with Rails and AJ + Current Attributes

# Load all the Railtie stuff like when `rails server`
ENV["KARAFKA_CLI"] = "true"

Bundler.require(:default)

require "tempfile"
require "active_job"
require "active_job/karafka"
require "action_controller"

ActiveJob::Base.extend Karafka::ActiveJob::JobExtensions
ActiveJob::Base.queue_adapter = :karafka

require "karafka/active_job/current_attributes"

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
end

Karafka.const_set(:License, mod)
require "karafka/pro/loader"

Karafka::Pro::Loader.require_all

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
assert Karafka.pro?
