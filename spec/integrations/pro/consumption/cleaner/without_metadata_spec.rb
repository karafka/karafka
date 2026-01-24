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

# We should be able to clean only payload when needed

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      message.payload if (message.offset % 2).zero?

      message.clean!(metadata: false)

      # We should fail if we try to deserialize a cleaned message
      if message.offset == 5
        begin
          message.payload
        rescue Karafka::Pro::Cleaner::Errors::MessageCleanedError
          DT[1] = true
        end

        message.key
        message.headers
      end

      DT[0] << true
    end
  end
end

draw_routes(Consumer)

elements = DT.uuids(100).map { |val| { val: val }.to_json }
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 100
end

assert DT.key?(1)
assert !DT.key?(2)
assert !DT.key?(3)
