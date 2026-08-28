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

# A subscription group async-locked via the jobless-locking API (used by advanced custom
# schedulers, here through the subscription groups coordinator) must keep its lock when a DIFFERENT
# subscription group's listener recovers from an error and clears its own state. JobsQueue#clear is
# per subscription group, but it used to flip the global async-locking fast-path flag off, which
# made the locked group's still-active lock be ignored - it would resume processing early.
#
# Here SG-a locks SG-b, then SG-a's listener is forced to reset once (which calls
# jobs_queue.clear(sg_a)) by raising from within SG-a's scheduling. SG-b, whose lock has a long
# timeout and is never released, must NOT process its messages.

become_pro!

# Forces exactly one reset of SG-a's listener (Listener#reset -> jobs_queue.clear(sg_a)) once SG-a
# has locked SG-b. Raising from on_schedule_consumption propagates to the listener fetch loop,
# which resets and then recovers.
class ResetOnceScheduler < Karafka::Pro::Processing::Schedulers::Default
  def on_schedule_consumption(jobs_array)
    if DT.key?(:b_locked) && !DT.key?(:reset_forced) && jobs_array.first&.group_id == DT[:sg_a_id]
      DT[:reset_forced] = true
      DT[:reset_at] = Time.now.to_f

      raise(StandardError, "force SG-a listener reset")
    end

    super
  end
end

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 1
  config.concurrency = 1
  config.internal.processing.scheduler_class = ResetOnceScheduler
end

class ConsumerA < Karafka::BaseConsumer
  def consume
    # Lock SG-b exactly once with a long timeout, so it stays locked for the whole test
    return if DT.key?(:b_locked)

    DT[:sg_a_id] = topic.subscription_group.id

    sg_b = Karafka::App.routes
      .flat_map(&:subscription_groups)
      .find { |sub| sub.topics.map(&:name).include?(DT.topics[1]) }

    subscription_groups_coordinator.pause(sg_b, :lock, timeout: 120_000)

    DT[:b_locked] = true
  end
end

class ConsumerB < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:b_processed] << message.offset }
  end
end

draw_routes do
  subscription_group :a do
    topic DT.topics[0] do
      consumer ConsumerA
    end
  end

  subscription_group :b do
    topic DT.topics[1] do
      consumer ConsumerB
    end
  end
end

# Two messages for SG-a: the first makes it lock SG-b, the second drives the scheduler reset
produce_many(DT.topics[0], DT.uuids(2))

def sg_b_lookup
  Karafka::App.routes
    .flat_map(&:subscription_groups)
    .find { |sub| sub.topics.map(&:name).include?(DT.topics[1]) }
end

start_karafka_and_wait_until do
  # Produce SG-b's messages only after it is locked, so they cannot be processed before the lock
  if DT.key?(:b_locked) && !DT.key?(:b_produced)
    DT[:b_produced] = true
    produce_many(DT.topics[1], DT.uuids(5))
  end

  # While SG-b is still locked (long timeout) and after SG-a's reset has cleared its own state,
  # assert SG-b processed nothing. With the fix, clearing SG-a's state leaves SG-b's lock in effect
  # so it stays paused; without the fix the global flag is flipped off and SG-b resumes early.
  # We assert here (not after shutdown) because a stuck-locked listener forces a non-graceful stop.
  if DT.key?(:reset_forced) && !DT.key?(:asserted) && (Time.now.to_f - DT[:reset_at]) > 8
    DT[:asserted] = true

    assert(
      DT[:b_processed].empty?,
      "SG-b processed #{DT[:b_processed].size} messages while it should have stayed async-locked"
    )

    # Release the lock so SG-b can drain and the server can stop gracefully. This also proves the
    # lock (not something else) was what held SG-b back.
    subscription_groups_coordinator = Karafka::Pro::Processing::ConsumerGroups::SubscriptionGroupsCoordinator.instance
    subscription_groups_coordinator.resume(sg_b_lookup, :lock)
  end

  DT.key?(:asserted) && DT[:b_processed].size >= 5
end
