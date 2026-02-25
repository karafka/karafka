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

# Karafka should support possibility of distributing work randomly when using virtual partitions
# Note that even when using random distribution, messages from different partitions will never
# mix within a batch.

setup_karafka do |config|
  config.concurrency = 5
  config.max_messages = 20
  config.initial_offset = "latest"
end

class VirtualPartitioner
  def initialize
    @current = 0
    @max = Karafka::App.config.concurrency - 1
    @set = (0..@max).to_a
  end

  def call(_)
    @current += 1
    @current = 0 if @current > @max
    @set[@current]
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[object_id] << message.offset
    end
  end
end

draw_routes do
  topic DT.topic do
    config(partitions: 2)
    consumer Consumer
    virtual_partitions(
      partitioner: VirtualPartitioner.new
    )
  end
end

start_karafka_and_wait_until do
  produce(DT.topic, "1", key: %w[a b c d].sample)
  produce(DT.topic, "1", key: %w[a b c d].sample)

  DT.data.values.sum(&:count) >= 1_000
end

# Two partitions, 5 jobs per each
assert_equal 10, DT.data.size
