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

# Long-running jobs are the most common real source of long pauses: the partition is paused for the
# whole duration of the job. A job that outlives the pause age therefore gets its partition's lag
# compensated while it runs, so operators see the real backlog growing instead of a value frozen at
# the moment the job started.

setup_karafka do |config|
  config.max_messages = 1
  config.kafka[:"statistics.interval.ms"] = 500
  config.internal.statistics.consumer_groups.lag_compensation.interval = 1_000
  config.internal.statistics.consumer_groups.lag_compensation.pause_age = 5_000
end

class Consumer < Karafka::BaseConsumer
  def consume
    unless DT.key?(:job_running)
      DT[:job_running] = true
      # A single job that runs well past the pause age; the partition stays paused throughout
      sleep(10)
    end

    mark_as_consumed!(messages.last)
    DT[:consumed] << messages.last.offset
  end
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  event[:statistics]["topics"].each do |_, topic_values|
    topic_values["partitions"].each do |partition_name, partition_values|
      next if partition_name == "-1"

      DT[:lags] << partition_values["consumer_lag"]
    end
  end
end

draw_routes do
  topic(DT.topic) do
    consumer Consumer
    long_running_job true
  end
end

produce_many(DT.topic, DT.uuids(1))

# Keep producing while the job runs; the producer stops a few emissions before the server
Thread.new do
  sleep(0.1) until DT.key?(:job_running)

  loop do
    produce_many(DT.topic, DT.uuids(1))
    sleep(0.3)

    break if DT[:lags].size >= 20
  end
end

start_karafka_and_wait_until do
  DT[:lags].size >= 25
end

# While the long-running job holds the partition paused past the pause age, the lag is compensated
# to reflect the backlog produced in the meantime instead of freezing
assert DT[:lags].max >= 15, "expected compensated lag during the long-running job, got max #{DT[:lags].max}"
