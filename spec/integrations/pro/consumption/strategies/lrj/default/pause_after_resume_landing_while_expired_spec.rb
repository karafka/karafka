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

# When an LRJ consumer resumes and then pauses again, the tracker is still expired from the resume
# while the client pause lands. The listener must not resume the partition in that window, or the
# user pause is lost and the message is consumed again while the first job still runs.
# A slow client pause makes the race window wider.

setup_karafka

module SlowUserPause
  def pause(*)
    super

    if DT.key?(:user_pause) && !DT.key?(:delayed)
      DT[:delayed] = true

      sleep(1)
    end
  end
end

Karafka::Connection::ConsumerGroups::Client.prepend(SlowUserPause)

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:times] << Process.clock_gettime(Process::CLOCK_MONOTONIC)

    return if DT[:times].size > 1

    resume
    DT[:user_pause] = true
    pause(messages.first.offset, 5_000)
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
  DT[:times].size >= 2
end

assert DT[:times][1] - DT[:times][0] >= 4.5
