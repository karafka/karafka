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

# When one partition reaches EOF more than once (because new data arrived after its first EOF
# and was consumed down to a second EOF), the iterator must not treat the repeated EOF of the
# same partition as if another partition finished. Iteration should continue until every
# partition has actually reached its end and all messages from all partitions were yielded.
#
# This guards against a bug where EOF events were counted globally instead of per partition:
# a single live partition receiving new data could exhaust the EOF budget for the whole
# subscription and silently terminate iteration while other partitions still had a backlog.

setup_karafka

draw_topics do
  topic DT.topic do
    partitions 2
  end
end

draw_routes do
  topic DT.topic do
    active false
  end
end

# Partition 0 starts empty, so its first EOF is registered right when iteration begins - no
# coordination needed. We then drip single messages into it, paced purely by partition 1
# consumption progress (every DRIP_EVERY yielded messages), never by wall-clock timers. Each
# drip the partition 0 fetcher catches up on ends in another EOF, so repeated partition 0 EOFs
# are guaranteed to occur while partition 1 still has a broker-side backlog.
P1_COUNT = 10_000
DRIP_EVERY = 100

produce_many(DT.topic, DT.uuids(P1_COUNT), partition: 1)

counts = Hash.new(0)
drips = 0

iterator = Karafka::Pro::Iterator.new(
  DT.topic,
  settings: {
    "auto.offset.reset": "beginning",
    # Keep the local prefetch queue tiny. With default prefetching, librdkafka would buffer the
    # entire partition 1 backlog within moments, and the late partition 0 message (plus its EOF
    # event) would be enqueued behind it, masking the early-termination scenario this spec
    # protects against. With a ~1KB queue, partition 1 data is fetched on demand, so the second
    # partition 0 EOF surfaces while most of partition 1 is still on the broker.
    "queued.max.messages.kbytes": 1,
    "fetch.message.max.bytes": 1_000
  }
)

iterator.each do |message|
  counts[message.partition] += 1

  # Drip one message into partition 0 after every DRIP_EVERY partition 1 messages. The pacing
  # is tied to consumption progress, not to time, so it holds on arbitrarily slow machines:
  # between two drips, ~DRIP_EVERY throttled yields pass, giving the partition 0 fetcher ample
  # cycles to deliver the previous drip and reach EOF again before the next one arrives
  if message.partition == 1 && (counts[1] % DRIP_EVERY).zero?
    drips += 1
    produce(DT.topic, "p0-drip-#{drips}", partition: 0)
  end

  # Throttle so partition 1's drain is bound by this loop while partition 0 drips are only
  # fetch-bound - each drip-consume-EOF round completes well within a DRIP_EVERY window
  sleep(0.005)
end

# At least the early drips must have been yielded (sanity check that partition 0 was live and
# cycling through EOFs during the iteration)
assert counts[0] >= 1, "expected at least one p0 drip message, got #{counts[0]}"

# Despite partition 0 EOFing twice, the whole partition 1 backlog must be yielded.
# Before the per-partition EOF tracking fix, iteration terminated right after the second
# partition 0 EOF, skipping most of partition 1.
assert_equal(
  P1_COUNT,
  counts[1],
  "iterator terminated early: yielded only #{counts[1]}/#{P1_COUNT} from partition 1"
)
