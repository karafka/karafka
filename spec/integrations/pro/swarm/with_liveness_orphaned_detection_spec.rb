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

# Pro liveness listener should detect orphaned nodes and exit them, same as the base listener.

setup_karafka do |config|
  config.swarm.nodes = 1
  config.internal.swarm.node_restart_timeout = 1_000
  config.internal.swarm.supervision_interval = 1_000
  config.internal.swarm.liveness_interval = 1_000
end

READER, WRITER = IO.pipe

Karafka.monitor.subscribe(
  Karafka::Pro::Swarm::LivenessListener.new
)

# Simulate orphaned state on first fork only so the restarted node works normally
Karafka::App.monitor.subscribe("swarm.manager.before_fork") do
  DT[:forks] << true
end

module Karafka
  module Swarm
    class Node
      alias_method :original_orphaned?, :orphaned?

      def orphaned?
        # First fork is "orphaned", subsequent ones are not
        DT[:forks].size <= 1
      end
    end
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts("1")
    WRITER.flush
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    manual_offset_management true
  end
end

produce_many(DT.topic, DT.uuids(10))

# The orphaned node should exit and be restarted. The restarted node will consume and write to pipe.
# We need at least 2 forks (first one exits as orphaned, second one runs normally).
done = []
start_karafka_and_wait_until(mode: :swarm) do
  done << READER.gets
  done.size >= 1 && DT[:forks].size >= 2
end

assert DT[:forks].size >= 2
