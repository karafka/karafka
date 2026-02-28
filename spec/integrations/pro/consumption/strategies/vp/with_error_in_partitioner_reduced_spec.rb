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

# When errors occur in partitioner, it should reduce to one partition whole batch

class Listener
  def on_error_occurred(event)
    DT[:errors] << event[:type]
  end
end

Karafka.monitor.subscribe(Listener.new)

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 10
  config.max_messages = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    DT[:consumers] << object_id

    messages.each do |message|
      DT[:offsets] << message.offset
    end

    DT[:b1] = true if DT[:offsets].size >= 10
  end
end

class Partitioner
  def call(_)
    DT[:raised] << true

    raise
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: Partitioner.new
    )
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  DT[:offsets].size >= 20 && DT.key?(:b1) && DT[:raised].size > 5
end

assert_equal 1, DT[:consumers].uniq.size
