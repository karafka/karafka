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

# With the KIP-848 consumer group protocol, when we boot more multiplexed listeners than there are
# partitions, the listeners that never get an assignment stay in the "init" join state with a
# rebalance age of 0. The multiplexing manager requires all active listeners to be "steady" before
# it rescales, so those idle listeners should not block the downscale that would remove them.
#
# Same setup as `dynamic_downscale_spec.rb` (which passes on the classic protocol) but with
# `group.protocol=consumer`. We expect to end up with 2 active listeners (one per partition).

setup_karafka(consumer_group_protocol: true) do |config|
  c_klass = config.internal.connection.conductor.class

  config.internal.connection.conductor = c_klass.new(1_000)
  config.concurrency = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

draw_topics do
  topic DT.topic do
    partitions 2
  end
end

draw_routes do
  subscription_group :sg do
    multiplexing(max: 5, min: 1, boot: 5, scale_delay: 1_000)

    topic DT.topic do
      consumer Consumer
    end
  end
end

# Last seen cgrp state per subscription group (listener)
cgrp_states = {}

Karafka.monitor.subscribe("statistics.emitted") do |event|
  cgrp = event[:statistics]["cgrp"]

  cgrp_states[event[:subscription_group_id]] = {
    state: cgrp["state"],
    join_state: cgrp["join_state"],
    rebalance_age: cgrp["rebalance_age"],
    assignment_size: cgrp["assignment_size"]
  }
end

# 1s scale delay, so 30s is way more than enough to go from 5 listeners down to 2
deadline = Time.now + 30
active_count = 0
report = []

start_karafka_and_wait_until do
  active = Karafka::Server.listeners.select(&:active?)
  active_count = active.size

  report = active.map do |listener|
    sg_id = listener.subscription_group.id
    "  #{sg_id}: #{cgrp_states[sg_id].inspect}"
  end

  # Before the boot listeners start there are 0 active, so require at least one
  (active_count.positive? && active_count <= 2) || Time.now > deadline
end

assert_equal(
  2,
  active_count,
  "Expected downscale to 2 listeners within 30s, got #{active_count}:\n#{report.join("\n")}"
)
