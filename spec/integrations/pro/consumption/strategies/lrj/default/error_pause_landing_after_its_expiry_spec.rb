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

# When the client pause of an LRJ retry lands after the listener could already expire the pause,
# the partition must still be resumed. Otherwise it stays paused and is never retried.
# A slow client pause makes the race window wider than the 1 ms pause timeout.

setup_karafka(allow_errors: %w[consumer.consume.error])

module SlowErrorPause
  def pause(*)
    sleep(1) if DT[:attempts].size == 1 && !DT.key?(:delayed) && (DT[:delayed] = true)

    super
  end
end

Karafka::Connection::ConsumerGroups::Client.prepend(SlowErrorPause)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:attempts] << attempt

    raise StandardError if attempt == 1
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    long_running_job true
  end
end

produce(DT.topic, "1")

start_karafka_and_wait_until do
  DT[:attempts].size >= 2
end

assert_equal [1, 2], DT[:attempts]
