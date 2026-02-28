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

# After VP collapses due to errors and then successfully processes, the error tracker should
# be empty on the next non-collapsed batch, indicating a clean recovery.

setup_karafka(allow_errors: %w[consumer.consume.error]) do |config|
  config.concurrency = 10
end

class Consumer < Karafka::BaseConsumer
  def consume
    if collapsed?
      DT[:errors_in_collapsed] << errors_tracker.to_a.dup
      # Succeed in collapsed mode
    else
      # Track errors_tracker state for non-collapsed batches
      DT[:errors_in_vp] << errors_tracker.to_a.dup

      if DT[:raised].empty?
        synchronize do
          unless DT[:raised].size >= 5
            DT[:raised] << true
            raise StandardError
          end
        end
      end

    end
    messages.each { |message| DT[0] << message.offset }
  end
end

DT[:iterator] = (0..9).cycle

draw_routes do
  topic DT.topic do
    consumer Consumer
    virtual_partitions(
      partitioner: ->(_msg) { DT[:iterator].next }
    )
    filter VpStabilizer
  end
end

produce_many(DT.topic, DT.uuids(100))

start_karafka_and_wait_until do
  # Wait until we have both collapsed errors and a successful VP batch after recovery
  DT[:errors_in_collapsed].size >= 1 && DT[:errors_in_vp].size >= 2
end

# The first VP batch should have had empty errors_tracker
assert DT[:errors_in_vp].first.empty?
# Collapsed batches should contain errors
assert DT[:errors_in_collapsed].any? { |errors| !errors.empty? }
