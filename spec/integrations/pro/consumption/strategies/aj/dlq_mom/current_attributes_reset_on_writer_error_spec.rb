# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# When a declared CurrentAttributes writer raises after setting its value while a job is being
# restored, all the values already set must be reset, so they do not leak into the next job
# processed on the same worker thread.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 1
end

setup_active_job

require "karafka/active_job/current_attributes"

draw_routes do
  active_job_topic DT.topic do
    dead_letter_queue topic: DT.topics[1], max_retries: 0
  end

  topic DT.topics[1] do
    active(false)
  end
end

class Current < ActiveSupport::CurrentAttributes
  attribute :tenant, :account

  def account=(value)
    super
    raise StandardError, "unknown account" if value == "missing"
  end
end

Karafka::ActiveJob::CurrentAttributes.persist(Current)

class RestoredJob < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[:restored_tenant] << Current.tenant
  end
end

class FollowingJob < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[:following] << [Current.tenant, Current.account]
  end
end

payload = RestoredJob.new.serialize.merge(
  "cattr_0" => { "tenant" => "leaked-tenant", "account" => "missing" }
)

Karafka.producer.produce_sync(topic: DT.topic, payload: payload.to_json)
FollowingJob.perform_later

start_karafka_and_wait_until do
  DT.key?(:following)
end

assert_equal [[nil, nil]], DT[:following], DT[:following]
assert_equal [], DT[:restored_tenant]
assert_equal Karafka::Pro::ActiveJob::Consumer, Karafka::App.routes.first.topics.first.consumer
