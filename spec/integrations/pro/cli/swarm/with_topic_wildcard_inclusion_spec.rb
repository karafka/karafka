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

# Karafka in swarm should honor a wildcard topic inclusion flag and only process the topics whose
# names match the pattern. This exercises the full swarm chain (CLI arg -> shared cli contract
# with the wildcard existence-check skip -> fork -> routing build -> swarm Topic#active?, which
# ANDs the routing filter with per-node assignment) with a wildcard rather than a literal value.

setup_karafka

READER, WRITER = IO.pipe

class Consumer < Karafka::BaseConsumer
  def consume
    WRITER.puts(topic.name)
    WRITER.flush
  end
end

# All three topics share a unique per-run base so there are no cross-run collisions, but only the
# two `-included-*` topics match the wildcard - the `-other` one must be filtered out.
BASE = DT.topic
INCLUDED_1 = "#{BASE}-included-1"
INCLUDED_2 = "#{BASE}-included-2"
OTHER = "#{BASE}-other"

draw_routes do
  consumer_group DT.group do
    topic INCLUDED_1 do
      consumer Consumer
    end

    topic INCLUDED_2 do
      consumer Consumer
    end

    topic OTHER do
      consumer Consumer
    end
  end
end

ARGV[0] = "swarm"
ARGV[1] = "--topics"
ARGV[2] = "#{BASE}-included-*"

produce_many(INCLUDED_1, DT.uuids(5))
produce_many(INCLUDED_2, DT.uuids(5))
produce_many(OTHER, DT.uuids(5))

thread = Thread.new { Karafka::Cli.start }

consumed = Set.new
while consumed.size < 2
  begin
    consumed << READER.gets.strip
  rescue Errno::EIO
    break
  end
end

Process.kill("QUIT", Process.pid)
thread.join

# Should only consume from the two wildcard-matched topics, not the non-matching one
assert(
  consumed.any?(INCLUDED_1),
  "Expected to consume from #{INCLUDED_1} but didn't"
)

assert(
  consumed.any?(INCLUDED_2),
  "Expected to consume from #{INCLUDED_2} but didn't"
)

assert(
  consumed.none?(OTHER),
  "Should NOT have consumed from non-matching topic #{OTHER}"
)
