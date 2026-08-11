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

# The legacy `:direct` encryption mode RSA-encrypts the payload directly, so it can only handle
# payloads up to the RSA key size minus the PKCS1 padding (key modulus - 11 bytes). This spec
# documents that boundary: payloads at the limit round-trip fine, while anything bigger raises
# at production time. Anything bigger requires the `:envelope` mode.

PUBLIC_KEY = fixture_file("rsa/public_key_1.pem")
PRIVATE_KEYS = { "1" => fixture_file("rsa/private_key_1.pem") }.freeze

# Max direct RSA payload for PKCS1 v1.5 padding
DIRECT_LIMIT = OpenSSL::PKey::RSA.new(PUBLIC_KEY).n.num_bytes - 11

setup_karafka do |config|
  config.encryption.active = true
  config.encryption.mode = :direct
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

at_limit = "a" * DIRECT_LIMIT
produce(DT.topic, at_limit)

# One byte over the limit cannot be encrypted with direct RSA at all. We assert only on the
# error class (RSAError or its PKeyError parent, depending on the Ruby/OpenSSL build) as the
# message wording differs across OpenSSL versions.
oversized_error = nil

begin
  produce(DT.topic, "a" * (DIRECT_LIMIT + 1))
rescue OpenSSL::PKey::PKeyError => e
  oversized_error = e
end

assert !oversized_error.nil?, "expected direct mode to fail on oversized payload"

start_karafka_and_wait_until do
  DT[:consumed].size >= 1
end

# The at-limit payload made it through the whole encrypted round trip
assert_equal [at_limit], DT[:consumed]
