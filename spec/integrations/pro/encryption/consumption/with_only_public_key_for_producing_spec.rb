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

# Karafka should work correctly when we configure it only to have public key and for messages
# producing only. Decryption will not be possible.

PUBLIC_KEY = fixture_file('rsa/public_key_1.pem')

setup_karafka do |config|
  config.encryption.active = true
  config.encryption.public_key = PUBLIC_KEY
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[message.metadata.partition] << message.raw_payload
      DT[:encryption] << message.headers['encryption']
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
  end
end

elements = DT.uuids(10).map { |uuid| "non-random-#{uuid}" }
produce_many(DT.topic, elements)

start_karafka_and_wait_until do
  DT[0].size >= 10
end

# There should be no raw info available
chunk = elements.first.split('-').first
assert(DT[0].none? { |payload| payload.include?(chunk) })

# Correct encryption version headers should be present
assert_equal %w[1], DT[:encryption].uniq
