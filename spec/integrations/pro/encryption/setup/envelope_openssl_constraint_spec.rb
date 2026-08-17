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

# Booting with the envelope encryption mode on an openssl gem too old for the EVP PKey API
# must fail during setup with a clear dependency constraints error. This is a first-boot
# process, so it also guards the ordering: the constraint registered in the feature pre_setup
# must be in the registry by the time the central config-phase verification runs.

# Simulate an old openssl gem. Integration specs are standalone scripts without RSpec, so
# stub_const is not available here
# rubocop:disable RSpec/RemoveConst
OpenSSL.send(:remove_const, :VERSION)
# rubocop:enable RSpec/RemoveConst
OpenSSL::VERSION = "2.2.1"

failed = false

begin
  setup_karafka do |config|
    config.encryption.active = true
    config.encryption.mode = :envelope
    config.encryption.public_key = fixture_file("rsa/public_key_1.pem")
    config.encryption.private_keys = { "1" => fixture_file("rsa/private_key_1.pem") }
  end
rescue Karafka::Errors::DependencyConstraintsError => e
  failed = true

  assert e.message.include?("openssl gem >= 3.0"), e.message
end

assert failed, "expected setup with envelope mode on old openssl to raise"
