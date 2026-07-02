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

# F29: `AssignmentsTracker#@generations` is incremented per assignment and intentionally never
# reduced on revoke. Keyed by the routing `Topic`, static topologies are bounded by the partition
# count, but pattern subscriptions inject a fresh, permanent `Topic` per discovered name - so the
# map (and the frozen deep copy `#generations` builds) grew for the whole process lifetime.
#
# Reproduced with a pattern that discovers several distinct topics while the generations bound is
# lowered: more topics than the bound are assigned and consumed, yet the generations map must stay
# bounded (the least-recently-assigned topics are evicted).

setup_karafka do |config|
  # Discover newly produced-to topics quickly so the pattern picks them up within the run.
  config.kafka[:"topic.metadata.refresh.interval.ms"] = 2_000
end

# Lower the bound (production default is 100_000) so a handful of discovered topics is enough to
# exercise the eviction. Done before the server starts, so the rebalance handlers observe it.
tracker = Karafka::Instrumentation::AssignmentsTracker
tracker.send(:remove_const, :GENERATIONS_TOPICS_LIMIT) if
  tracker.const_defined?(:GENERATIONS_TOPICS_LIMIT)
tracker.const_set(:GENERATIONS_TOPICS_LIMIT, 2)

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each { |message| DT[:topics] << message.topic }
  end
end

PREFIX = "#{DT.topic}gen"
PATTERN_REGEXP = /#{Regexp.escape(PREFIX)}/

draw_routes(create_topics: false) do
  pattern(PATTERN_REGEXP) do
    consumer Consumer
  end
end

TOPICS = Array.new(5) { |i| "#{PREFIX}-#{i}" }

start_karafka_and_wait_until do
  unless @produced
    TOPICS.each { |topic| produce(topic, "1") }
    @produced = true
  end

  # Wait until at least 4 distinct pattern-discovered topics have been assigned and consumed - that
  # is more than the lowered bound of 2, so the eviction must have engaged.
  DT[:topics].uniq.size >= 4
end

# More than the bound's worth of distinct topics were assigned...
assert(DT[:topics].uniq.size >= 4, "expected >= 4 distinct topics, got #{DT[:topics].uniq.tally}")

# ...yet the generations map stayed bounded (on master it would hold every discovered topic).
assert(
  tracker.generations.size <= 2,
  "generations map grew unbounded: #{tracker.generations.size} topics"
)
