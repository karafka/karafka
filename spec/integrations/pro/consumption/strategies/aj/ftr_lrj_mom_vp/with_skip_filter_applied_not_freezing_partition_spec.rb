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

# When AJ + FTR + LRJ + MoM + VP are combined and a filter returns applied? true with action
# :skip, the partition should NOT become permanently frozen.

setup_active_job

setup_karafka do |config|
  config.max_messages = 5
  config.kafka[:"max.poll.interval.ms"] = 10_000
  config.kafka[:"session.timeout.ms"] = 10_000
end

class SkipFilter < Karafka::Pro::Processing::Filters::Base
  def apply!(messages)
    @applied = false
    @cursor = nil

    messages.delete_if do |message|
      parsed = JSON.parse(message.raw_payload)
      value = parsed["arguments"]&.first

      if value.is_a?(Integer) && value.odd?
        @applied = true
        @cursor = message
        true
      else
        false
      end
    rescue JSON::ParserError
      false
    end
  end
end

class Job < ActiveJob::Base
  queue_as DT.topic

  def perform(value)
    DT[:processed] << value
  end
end

draw_routes do
  active_job_topic DT.topic do
    max_messages 5
    long_running_job true
    filter ->(*) { SkipFilter.new }
    virtual_partitions(
      partitioner: ->(_) { rand(2) }
    )
  end
end

20.times { |i| Job.perform_later(i) }

start_karafka_and_wait_until do
  DT[:processed].size >= 10
end

assert DT[:processed].size >= 10
