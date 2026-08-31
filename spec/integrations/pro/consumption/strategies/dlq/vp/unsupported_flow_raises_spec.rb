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

# The VP DLQ strategy must also raise Karafka::Errors::UnsupportedCaseError - not a NameError -
# when a custom strategy returns an unsupported flow symbol.

setup_karafka(allow_errors: true) do |config|
  config.concurrency = 2
end

Karafka.monitor.subscribe("error.occurred") do |event|
  DT[:errors] << event[:error]
end

class UnsupportedFlowStrategy
  def call(*_args)
    :unsupported_flow
  end
end

class Consumer < Karafka::BaseConsumer
  def consume
    raise StandardError
  end
end

draw_routes do
  topic DT.topics[0] do
    consumer Consumer

    virtual_partitions(
      partitioner: ->(_) { rand(10) }
    )

    dead_letter_queue(
      topic: DT.topics[1],
      strategy: UnsupportedFlowStrategy.new
    )
  end
end

produce_many(DT.topics[0], DT.uuids(5))

start_karafka_and_wait_until do
  DT[:errors].any? { |error| error.is_a?(Karafka::Errors::UnsupportedCaseError) }
end

assert DT[:errors].any? { |error| error.is_a?(Karafka::Errors::UnsupportedCaseError) }
