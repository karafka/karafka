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

# With the `:envelope` encryption mode, payloads much larger than the RSA key capacity
# (like full medical-record style documents) should encrypt, transport and decrypt correctly,
# including fingerprint verification of the decrypted content

PUBLIC_KEY = fixture_file("rsa/public_key_1.pem")
PRIVATE_KEYS = { "1" => fixture_file("rsa/private_key_1.pem") }.freeze

setup_karafka do |config|
  config.encryption.active = true
  config.encryption.mode = :envelope
  config.encryption.public_key = PUBLIC_KEY
  config.encryption.private_keys = PRIVATE_KEYS
  config.encryption.fingerprinter = Digest::SHA256
end

class Consumer < Karafka::BaseConsumer
  def consume
    messages.each do |message|
      DT[:consumed] << message.payload
      # The fingerprint header must carry the digest of the decrypted payload
      DT[:fingerprints_valid] << (
        message.headers["encryption_fingerprint"] == Digest::SHA256.hexdigest(message.payload)
      )
    end
  end
end

draw_routes do
  topic DT.topic do
    consumer Consumer
    deserializer ->(message) { message.raw_payload.to_s }
  end
end

# Realistic large payloads, far beyond any direct RSA capacity
elements = Array.new(5) do |i|
  {
    record_id: i,
    patient: { name: "x" * 500, history: Array.new(20) { "y" * 200 } },
    telemetry: Array.new(100) { rand.to_s }
  }.to_json
end

elements.each { |element| produce(DT.topic, element) }

start_karafka_and_wait_until do
  DT[:consumed].size >= 5
end

assert_equal elements.sort, DT[:consumed].sort

# Fingerprint verification really ran against the decrypted content
assert_equal 5, DT[:fingerprints_valid].size
assert DT[:fingerprints_valid].all?

# Sanity: those payloads are indeed way above the direct RSA ceiling
assert elements.all? { |element| element.bytesize > 1_000 }
