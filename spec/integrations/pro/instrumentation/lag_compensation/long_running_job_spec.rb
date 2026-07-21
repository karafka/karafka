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
    # Commit first so there is a committed offset to derive the lag from: with nothing committed
    # librdkafka reports consumer_lag as -1 and the compensator has no base to compute against
    mark_as_consumed!(messages.last)
    DT[:consumed] << messages.last.offset

    return if DT.key?(:job_running)

    DT[:job_running] = true
    # A single job that runs well past the pause age; the partition stays paused throughout. Mark
    # its end so we stop sampling: once the job finishes the partition resumes and librdkafka
    # reports the real (live) lag on its own, which must not be mistaken for compensation.
    sleep(12)
    DT[:job_done] = true
  end
end

Karafka::App.monitor.subscribe("statistics.emitted") do |event|
  # Only sample while the job holds the partition paused. This is the whole point: without
  # compensation the lag would stay frozen for the entire job (it only jumps once the job ends and
  # the partition resumes and fetches), so sampling past the job would pass even with the feature
  # off.
  next unless DT.key?(:job_running)
  next if DT.key?(:job_done)

  event[:statistics]["topics"].each do |_, topic_values|
    topic_values["partitions"].each do |partition_name, partition_values|
      next if partition_name == "-1"

      DT[:job_lags] << partition_values["consumer_lag"]
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

# Keep producing while the job runs; the producer stops a few samples before the server does
Thread.new do
  sleep(0.1) until DT.key?(:job_running)

  loop do
    produce_many(DT.topic, DT.uuids(1))
    sleep(0.3)

    break if DT[:job_lags].size >= 12 || DT.key?(:job_done)
  end
end

start_karafka_and_wait_until do
  # Enough in-job samples to have crossed the pause age (the job still runs, so all of these are
  # from the paused window)
  DT[:job_lags].size >= 15
end

# While the long-running job holds the partition paused past the pause age, the lag is compensated
# to reflect the backlog produced in the meantime instead of freezing at the job's start
assert DT[:job_lags].max >= 15, "expected compensated lag during the long-running job, got max #{DT[:job_lags].max}"
