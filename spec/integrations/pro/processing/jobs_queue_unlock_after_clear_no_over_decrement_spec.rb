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

# #lock/#unlock are the jobless-locking primitives advanced custom schedulers use directly on the
# real, running Karafka::Server.jobs_queue (there is no built-in wrapper for the non-async variant,
# unlike lock_async/unlock_async which go through SubscriptionGroupsCoordinator). This reproduces
# the #44997 regression end-to-end against that live queue instance, not a bare unit-test double:
# a job is locked, its subscription group is then cleared (exactly what a listener reset does on
# recovery - Connection::Listener#reset calls jobs_queue.clear), and only afterwards is the same
# job unlocked - the sequence the bug report describes.
#
# Before the fix: #unlock decremented `waiting` unconditionally before checking whether the job
# was still tracked, so on top of the (still legitimate) JobsQueueSynchronizationError, the
# already-correct decrement #clear performed was duplicated, leaving `waiting` negative.
# After the fix: #unlock only decrements when it actually finds the job, so `waiting` stays 0.

become_pro!

setup_karafka

class DummyConsumer < Karafka::BaseConsumer
  def consume
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer DummyConsumer
  end
end

Job = Struct.new(:group_id)

start_karafka_and_wait_until do
  next true if DT.key?(:done)

  subscription_group = Karafka::App
    .routes
    .flat_map(&:subscription_groups)
    .find { |sub| sub.topics.map(&:name).include?(DT.topics[0]) }

  group_id = subscription_group.id
  queue = Karafka::Server.jobs_queue
  job = Job.new(group_id)

  # The listener already registered this group with the queue on boot (Listener#initialize calls
  # jobs_queue.register before the fetch loop starts), so the group is ready to use here.
  queue.lock(job)

  # A listener reset for this group happening while the job is still locked - e.g. the listener
  # recovering from a raised error - resets waiting/in_waiting/locks for the group.
  queue.clear(group_id)

  begin
    queue.unlock(job)
  rescue Karafka::Errors::JobsQueueSynchronizationError
    # Still the expected, legitimate outcome: the job is no longer tracked after #clear, so
    # #unlock correctly reports it - this is not what this spec is guarding against.
    DT[:raised] = true
  end

  DT[:waiting_after_unlock] = queue.statistics[:waiting]
  DT[:done] = true

  true
end

assert(DT[:raised], "expected #unlock to still raise JobsQueueSynchronizationError after #clear")

assert_equal(
  0,
  DT[:waiting_after_unlock],
  "expected waiting to stay 0 after #clear + #unlock, got #{DT[:waiting_after_unlock]} " \
  "(negative means #unlock over-decremented on top of what #clear already accounted for)"
)
