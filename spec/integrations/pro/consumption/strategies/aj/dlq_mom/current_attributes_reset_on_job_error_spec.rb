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

# CurrentAttributes loaded from a job's payload must be reset even when the job raises, so they do
# not leak into the next job processed on the same worker thread. The reset previously ran only
# after a successful execution, so a raising job left its attributes (e.g. tenant/user context)
# set for the following job that carries none of its own.
#
# A single worker (concurrency 1) processes a failing job carrying a tenant, which is dispatched
# to the DLQ (max_retries 0) so the next job - enqueued with no tenant - runs on the same thread.
# That following job must observe a nil tenant, not the failed job's leaked value.

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
  attribute :tenant
end

Karafka::ActiveJob::CurrentAttributes.persist(Current)

class FailingJob < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[:failing_tenant] << Current.tenant

    raise(StandardError, "boom")
  end
end

class FollowingJob < ActiveJob::Base
  queue_as DT.topic

  def perform
    DT[:following_tenant] << Current.tenant
  end
end

# The failing job carries a tenant; we reset before enqueuing the following job so it carries none
Current.tenant = "secret-tenant"
FailingJob.perform_later
Current.reset
FollowingJob.perform_later

start_karafka_and_wait_until do
  DT.key?(:following_tenant)
end

# Sanity: the failing job did load the tenant from its payload
assert_equal ["secret-tenant"], DT[:failing_tenant], DT[:failing_tenant]

# The failing job's tenant must not leak into the following job that carries none of its own
assert_equal [nil], DT[:following_tenant], DT[:following_tenant]
