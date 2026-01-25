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

# Karafka should recover from this error and move on without publishing anything to the DLQ

setup_active_job

setup_karafka(allow_errors: true) do |config|
  config.max_messages = 10
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

class DlqConsumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[1] << message.headers["source_offset"].to_i
    end
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[0] << value
    sleep(value.to_f / 20)
    raise StandardError if DT[0].size < 10
  end
end

draw_routes do
  active_job_topic DT.topic do
    # We set it to 100k so it never reaches it and always recovers
    dead_letter_queue topic: DT.topics[1], max_retries: 100_000
    long_running_job true
    virtual_partitions(
      partitioner: ->(_) { rand(10) }
    )
  end

  topic DT.topics[1] do
    consumer DlqConsumer
  end
end

5.times { |value| Job.perform_later(value) }

start_karafka_and_wait_until do
  DT[0].size >= 10
end

assert DT[1].empty?
