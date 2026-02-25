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

module Karafka
  module Pro
    module Encryption
      # Encryption related messages components
      module Messages
        # Middleware for WaterDrop. It automatically encrypts messages payload.
        # It is injected only if encryption is enabled.
        # It also fingerprints the payload for verification if fingerprinting was enabled
        class Middleware
          include Helpers::ConfigImporter.new(
            cipher: %i[encryption cipher],
            version: %i[encryption version],
            fingerprinter: %i[encryption fingerprinter]
          )

          # @param message [Hash] WaterDrop message hash
          # @return [Hash] hash with encrypted payload and encryption version indicator
          def call(message)
            payload = message[:payload]

            message[:headers] ||= {}
            message[:headers]["encryption"] = version
            message[:payload] = cipher.encrypt(payload)

            return message unless fingerprinter

            message[:headers]["encryption_fingerprint"] = fingerprinter.hexdigest(payload)

            message
          end
        end
      end
    end
  end
end
