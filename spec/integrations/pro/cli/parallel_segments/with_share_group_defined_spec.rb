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

# The parallel segments CLI must keep working when the routing also describes a share group:
# collecting applicable groups iterates all routes and before the fix crashed with NoMethodError
# calling #parallel_segments? on the share group.

setup_karafka

draw_routes(create_topics: false) do
  consumer_group DT.group do
    parallel_segments(
      count: 2,
      partitioner: ->(msg) { msg.key }
    )

    topic DT.topic do
      active(false)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end

  share_group "sg" do
    topic "share-topic" do
      active(false)
      consumer Class.new(Karafka::BaseConsumer)
    end
  end
end

command = Karafka::Pro::Cli::ParallelSegments::Distribute.new({})
groups = command.send(:applicable_groups)

# Only the parallel-segments consumer groups should be collected, keyed by their origin name
assert_equal [DT.group], groups.keys
assert_equal 2, groups.fetch(DT.group).size
assert(groups.fetch(DT.group).all?(&:consumer_group?))
