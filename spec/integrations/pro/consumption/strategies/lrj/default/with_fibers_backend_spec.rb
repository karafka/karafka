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

# Long Running Jobs should work with the fibers workers backend: the non-blocking job releases
# the jobs queue lock (tick) from within a fiber and long fiber jobs do not block polling

setup_karafka do |config|
  config.workers.backend = :fibers
  config.workers.concurrency = 5
  config.max_messages = 5
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:threads] << Thread.current.name

    # Long, scheduler-aware work inside an LRJ fiber
    sleep(2)

    messages.each { |message| DT[:offsets] << message.offset }
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
  end
end

produce_many(DT.topic, DT.uuids(10))

start_karafka_and_wait_until do
  DT[:offsets].uniq.size >= 10
end

# All the LRJ work ran on carrier-hosted fibers
assert(DT[:threads].all? { |name| name.match?(/karafka\.carrier#\d+/) }, DT[:threads])

# All data was consumed in order
assert_equal (0..9).to_a, DT[:offsets].uniq.sort
