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

# Many consumers pausing their subscription group with new lock ids
# (subscription_groups_coordinator.pause, #lock_async underneath) while the listener waits on the
# same group should not fail. The listener's #wait? removes expired locks from the group locks
# Hash with #delete_if; if it did that without the jobs queue mutex, a consumer adding a new lock
# key in the meantime raised "can't add a new key into hash during iteration" in #consume.

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 1
  config.concurrency = 5
end

PARTITIONS = 5
LOCKS_PER_CONSUME = 200_000

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:error]
end

class Consumer < Karafka::BaseConsumer
  def consume
    subscription_group = topic.subscription_group

    LOCKS_PER_CONSUME.times do |i|
      subscription_groups_coordinator.pause(
        subscription_group,
        [partition, messages.last.offset, i],
        timeout: 2_000
      )
    end

    DT[:consumed] << partition
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: PARTITIONS)
    consumer Consumer
    long_running_job true
  end
end

PARTITIONS.times do |partition|
  produce(DT.topic, DT.uuid, partition: partition)
end

start_karafka_and_wait_until do
  DT[:consumed].size >= PARTITIONS || DT[:errors].any?
end

assert_equal [], DT[:errors].map { |error| "#{error.class}: #{error.message}" }
