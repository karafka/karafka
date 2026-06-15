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

# When encryption is active, a tombstone (a record with a key and a nil payload) has nothing to
# encrypt or decrypt. It should be produced and consumed as a regular tombstone (nil payload), while
# normal messages are still encrypted on produce and decrypted on consume. Without this, producing a
# tombstone crashes in the encryption middleware (`cipher.encrypt(nil)`).

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
      DT[:results] << {
        payload: message.payload,
        tombstone: message.tombstone?,
        raw_nil: message.raw_payload.nil?
      }
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    # Plain payloads (not JSON), so the default deserializer would choke - mirror the other
    # encryption specs and just stringify
    deserializer ->(message) { message.raw_payload.to_s }
  end
end

NORMAL = SecureRandom.uuid

# A normal (encrypted) message and a tombstone (nil payload), both keyed so the tombstone qualifies
produce(DT.topic, NORMAL, key: "normal", partition: 0)
produce(DT.topic, nil, key: "tombstone", partition: 0)

start_karafka_and_wait_until do
  DT[:results].size >= 2
end

normal_result = DT[:results].find { |r| !r[:tombstone] }
tombstone_result = DT[:results].find { |r| r[:tombstone] }

# The normal message round-tripped through encryption
assert !normal_result.nil?, "normal message was not consumed"
assert_equal NORMAL, normal_result[:payload]

# The tombstone round-tripped as a real tombstone (nil payload) rather than crashing
assert !tombstone_result.nil?, "tombstone was not consumed"
assert tombstone_result[:raw_nil], "tombstone payload should remain nil"
assert_equal 2, DT[:results].size
