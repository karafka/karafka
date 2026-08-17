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

# Messages encrypted with the legacy `:direct` mode (pre-envelope format at rest) and messages
# encrypted with the `:envelope` mode must both be decryptable by the same consumer, as the
# formats are auto-recognized. This guards backwards compatibility of already produced data and
# the safety of staged envelope rollouts.

PUBLIC_KEY = fixture_file("rsa/public_key_1.pem")
PRIVATE_KEYS = { "1" => fixture_file("rsa/private_key_1.pem") }.freeze

setup_karafka do |config|
  config.encryption.active = true
  config.encryption.public_key = PUBLIC_KEY
  config.encryption.private_keys = PRIVATE_KEYS
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.payload
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    deserializer ->(message) { message.raw_payload.to_s }
  end
end

# Produce first with the legacy direct format (simulates data at rest from older versions)
Karafka::App.config.encryption.mode = :direct
legacy_elements = DT.uuids(5)
legacy_elements.each { |element| produce(DT.topic, element) }

# And then with the envelope format, including payloads impossible in the direct mode
Karafka::App.config.encryption.mode = :envelope
envelope_elements = Array.new(5) { |i| "envelope-#{i}-#{"x" * 2_000}" }
envelope_elements.each { |element| produce(DT.topic, element) }

start_karafka_and_wait_until do
  DT[:consumed].size >= 10
end

assert_equal (legacy_elements + envelope_elements).sort, DT[:consumed].sort
