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

# We should be able to use automatic cleaning to get rid of the key and headers
#
# We should fail when trying to deserialize a cleaned details

setup_karafka

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each(clean: true) do |message|
      message.payload if (message.offset % 2).zero?

      DT[0] << true
    end

    # We should fail if we try to deserialize a cleaned message key
    begin
      messages.first.key
    rescue Karafka::Pro::Cleaner::Errors::MessageCleanedError
      DT[1] = true
    end

    # We should fail if we try to deserialize a cleaned message headers
    begin
      messages.first.headers
    rescue Karafka::Pro::Cleaner::Errors::MessageCleanedError
      DT[2] = true
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
assert DT.key?(2)
