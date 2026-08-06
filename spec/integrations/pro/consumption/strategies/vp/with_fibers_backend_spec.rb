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

# With the fibers workers backend, virtual partitions should parallelize IO-bound processing of
# a single topic partition as fibers multiplexed on a single carrier thread

setup_karafka do |config|
  config.workers.backend = :fibers
  config.workers.concurrency = 5
  config.workers.carrier_threads = 1
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:threads] << Thread.current.name
    DT[:objects] << object_id
    DT[:starts] << Process.clock_gettime(Process::CLOCK_MONOTONIC)
    # Scheduler-aware blocking operation simulating IO
    sleep(1)
    DT[:stops] << Process.clock_gettime(Process::CLOCK_MONOTONIC)

    messages.each { |message| DT[:offsets] << message.offset }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(msg) { msg.raw_payload }
    )
  end
end

produce_many(DT.topic, DT.uuids(20))

start_karafka_and_wait_until do
  DT[:offsets].uniq.size >= 20
end

# More than one virtual partition consumer instance processed the data
assert DT[:objects].uniq.size >= 2

# All the VP work ran as fibers on the single carrier thread
assert_equal ["karafka.carrier#0"], DT[:threads].uniq

# And the virtual partitions processing overlapped in time, which a single thread can only
# achieve with fibers
intervals = DT[:starts].zip(DT[:stops])
overlap = intervals.combination(2).any? do |(start1, stop1), (start2, stop2)|
  start1 < stop2 && start2 < stop1
end

assert overlap, "expected virtual partitions to overlap on the carrier thread"
