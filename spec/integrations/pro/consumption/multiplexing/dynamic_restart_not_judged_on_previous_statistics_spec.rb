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


# A listener restarted by an upscale should not be judged on the statistics of its previous
# consumer. With statistics emitted rarely, such stale statistics report a steady state, so the
# restarted listener would be scaled down again at once, before it gets an assignment.

setup_karafka do |config|
  c_klass = config.internal.connection.conductor.class

  config.internal.connection.conductor = c_klass.new(1_000)
  config.concurrency = 1
  config.kafka[:"statistics.interval.ms"] = 5_000
  config.kafka[:"topic.metadata.refresh.interval.ms"] = 2_000
end

class Consumer < Karafka::BaseConsumer
  def consume
  end
end

draw_topics do
  topic DT.topic do
    partitions 1
  end
end

draw_routes do
  subscription_group :sg do
    multiplexing(max: 2, min: 1, boot: 2, scale_delay: 1_000)

    topic DT.topic do
      consumer Consumer
    end
  end
end

stops = 0

Karafka.monitor.subscribe("connection.listener.stopping") { stops += 1 }

scaled_down = false
scaled_up_at = nil
stops_before_shutdown = nil

start_karafka_and_wait_until do
  active = Karafka::Server.listeners.count(&:active?)

  if !scaled_down && active == 1
    scaled_down = true
    # With more partitions the remaining listener gets all of them, so an upscale follows
    Karafka::Admin.create_partitions(DT.topic, 4)
  end

  scaled_up_at ||= Time.now if scaled_down && active == 2

  # The previous consumer statistics are a few seconds old when the listener is restarted, so we
  # give it a few statistics intervals to show it is not scaled down again
  next false unless scaled_up_at && Time.now - scaled_up_at > 20

  stops_before_shutdown = stops

  true
end

# Only the initial downscale
assert_equal 1, stops_before_shutdown
