# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

# When using the pro adapter, we should be able to use partitioner that will allow us to process
# ActiveJob jobs in their scheduled order using multiple partitions. We should be able to get
# proper results when using `:partition_key`.

setup_karafka do |config|
  config.initial_offset = "latest"
end

setup_active_job

draw_routes do
  active_job_topic DT.topic do
    config(partitions: 3)
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  karafka_options(
    dispatch_method: :produce_sync,
    partitioner: ->(job) { job.arguments.first[0] },
    partition_key_type: :partition_key
  )

  def perform(value1)
    DT[0] << value1
  end
end

counts = 0

# First loop kicks in before initialization of the connection and we want to publish after, that
# is why we don't run it on the first run
Karafka::App.monitor.subscribe("connection.listener.fetch_loop") do
  counts += 1

  if counts == 20
    # We dispatch in order per partition, in case it all would go to one without partitioner or
    # in case it would fail, the order will break
    2.downto(0) do |partition|
      3.times do |iteration|
        Job.perform_later("#{partition}#{iteration}")
      end
    end
  end
end

start_karafka_and_wait_until do
  DT[0].size >= 9
end

groups = DT[0].group_by { |element| element[0] }
groups.transform_values! { |group| group.map(&:to_i) }

groups.each_value do |values|
  assert_equal values.sort, values
end
