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

# Every completed job ticks its subscription group semaphore on the live
# Karafka::Server.jobs_queue. For LRJ (non-blocking) jobs #wait? is false from the start, so the
# OSS wait loop - the only other thing popping that semaphore - never runs. Before #3315 those
# signals were never consumed and the semaphore grew with every completed job for the whole
# process lifetime. After the fix #wait drains stale signals up front on every listener loop, so
# the semaphore stays bounded no matter how many jobs complete.

setup_karafka do |config|
  # One message per batch, so every message becomes its own LRJ job and its own tick
  config.max_messages = 1
end

MESSAGES = 30

class Consumer < Karafka::BaseConsumer
  def consume
    semaphore = Karafka::Server
      .jobs_queue
      .instance_variable_get(:@semaphores)
      .fetch(topic.subscription_group.id)

    DT[:sizes] << semaphore.size
    DT[:offsets] << messages.last.offset
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
  end
end

produce_many(DT.topic, DT.uuids(MESSAGES))

start_karafka_and_wait_until do
  DT[:offsets].size >= MESSAGES
end

# Sanity: enough LRJ jobs completed for an unbounded semaphore to show up as clear growth
assert DT[:sizes].size >= MESSAGES

assert(
  DT[:sizes].max <= 5,
  "expected the LRJ semaphore to stay bounded, got sizes up to #{DT[:sizes].max} " \
  "after #{DT[:sizes].size} jobs (growth with job count means stale ticks are never drained)"
)
