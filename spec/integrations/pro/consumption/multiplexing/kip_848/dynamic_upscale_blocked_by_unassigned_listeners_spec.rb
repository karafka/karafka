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

# With the KIP-848 consumer group protocol, listeners that never receive an assignment stay in the
# "init" join state with a rebalance age of 0. The multiplexing manager requires all active
# listeners to be "steady" before it rescales, so such idle listeners should not block an upscale
# needed by other listeners from the same subscription group.
#
# Server-side KIP-848 assignors balance partitions, so a lasting state where one listener holds
# multiple partitions of a topic while another one is idle cannot be produced by the broker in a
# single process. We keep the real broker state (more listeners than partitions, so idle listeners
# really sit in "init") and only simulate the upscale demand: while `scale_up` runs, every
# assignment reports one extra fake partition. The stability checks stay untouched.
#
# `min: 3` prevents downscaling, so the only valid action is an upscale.

# Marks that we are inside of the manager `scale_up`
module SimulatedUpscaleDemand
  def scale_up
    Thread.current[:simulated_upscale_demand] = true
    super
  ensure
    Thread.current[:simulated_upscale_demand] = false
  end
end

# Makes every assignment look like a multi-partition one, but only for `scale_up`
module SimulatedMultiPartitionAssignments
  def assignments
    current = super

    return current unless Thread.current[:simulated_upscale_demand]

    current.transform_values { |partitions| partitions + [-1] }
  end
end

setup_karafka(consumer_group_protocol: true) do |config|
  c_klass = config.internal.connection.conductor.class

  config.internal.connection.conductor = c_klass.new(1_000)
  config.concurrency = 1
end

# Pro components are loaded during setup, so we patch after it
Karafka::Pro::Connection::ConsumerGroups::Manager.prepend(SimulatedUpscaleDemand)
Karafka::App.singleton_class.prepend(SimulatedMultiPartitionAssignments)

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
    multiplexing(max: 5, min: 3, boot: 3, scale_delay: 1_000)

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

# 1s scale delay, so 30s is way more than enough for an upscale to happen
deadline = Time.now + 30
max_active = 0
report = []

start_karafka_and_wait_until do
  active = Karafka::Server.listeners.select(&:active?)
  max_active = [max_active, active.size].max

  report = active.map do |listener|
    sg_id = listener.subscription_group.id
    "  #{sg_id}: #{cgrp_states[sg_id].inspect}"
  end

  max_active > 3 || Time.now > deadline
end

assert(
  max_active > 3,
  "Expected an upscale above 3 listeners within 30s, stayed at #{max_active}:\n" \
  "#{report.join("\n")}"
)
