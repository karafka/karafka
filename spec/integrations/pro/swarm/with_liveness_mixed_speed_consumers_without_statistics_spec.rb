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

# When statistics are disabled, one consumer is very slow (80s) and another is fast,
# and consuming_ttl is set lower than the slow consumer's processing time, the node
# should be killed because the slow consumer exceeds consuming_ttl even though the
# fast consumer is healthy.

setup_karafka do |config|
  config.swarm.nodes = 1
  config.kafka[:"statistics.interval.ms"] = 0
  config.internal.tick_interval = 1_000
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 1_000
  config.internal.swarm.liveness_interval = 1_000
end

READER, WRITER = IO.pipe

Karafka.monitor.subscribe(
  Karafka::Pro::Swarm::LivenessListener.new(
    consuming_ttl: 5_000
  )
)

class SlowConsumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:done)
      WRITER.puts("1")
      WRITER.flush
      DT[:done] = true
    end

    # Prevents post-kill restarted node from sleeping as well
    mark_as_consumed(messages.last)

    sleep(180) if messages.last.offset.zero?
  end
end

class FastConsumer < Karafka::BaseConsumer
  def consume
    DT[:fast_consumed] = true
    mark_as_consumed(messages.last)
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer SlowConsumer
    manual_offset_management true
    max_messages 1
  end

  topic DT.topics[1] do
    consumer FastConsumer
    manual_offset_management true
    max_messages 1
  end
end

produce_many(DT.topics[0], DT.uuids(2))
produce_many(DT.topics[1], DT.uuids(2))

# Node should be killed because slow consumer exceeds consuming_ttl.
# Wait for 2 forks (original + restart after kill).
done = []
start_karafka_and_wait_until(mode: :swarm) do
  done << READER.gets
  done.size >= 2
end
