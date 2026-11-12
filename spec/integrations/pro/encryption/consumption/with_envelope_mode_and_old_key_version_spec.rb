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

# With the `:envelope` mode, messages produced with an old key version should be decrypted after
# the switch to a new version, as long as the old private key is still present

PUBLIC_KEY = fixture_file("rsa/public_key_1.pem")

PRIVATE_KEYS = {
  "1" => fixture_file("rsa/private_key_1.pem"),
  "2" => fixture_file("rsa/private_key_2.pem")
}.freeze

setup_karafka do |config|
  config.encryption.active = true
  config.encryption.mode = :envelope
  config.encryption.version = "2"
  config.encryption.public_key = PUBLIC_KEY
  config.encryption.private_keys = PRIVATE_KEYS
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:versions] << message.headers["encryption"]
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

# Simulate using old version by changing version just for production
Karafka::App.config.encryption.version = "1"

elements = DT.uuids(10)
produce_many(DT.topic, elements)

Karafka::App.config.encryption.version = "2"

start_karafka_and_wait_until do
  DT[:consumed].size >= 10
end

assert_equal elements, DT[:consumed]
assert_equal %w[1], DT[:versions].uniq

# Records at rest are envelopes: the envelope version byte and more than the 512 bytes of a
# direct RSA-4096 ciphertext
raws = Karafka::Admin.read_topic(DT.topic, 0, 10).map(&:raw_payload)
assert_equal 10, raws.size
assert(raws.all? { |raw| raw.bytesize > 512 && raw.b[0] == "\x01".b })
