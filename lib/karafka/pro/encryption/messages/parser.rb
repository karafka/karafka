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
      module Messages
        # Pro parser that takes into consideration encryption usage
        # @note There may be a case where someone decides not to encrypt data and we start getting
        #   unencrypted payloads. That is why we always rely on message headers for encryption
        #   indication.
        class Parser < Karafka::Messages::Parser
          include Helpers::ConfigImporter.new(
            cipher: %i[encryption cipher],
            active: %i[encryption active],
            fingerprinter: %i[encryption fingerprinter]
          )

          # @param message [::Karafka::Messages::Message]
          # @return [Object] deserialized payload
          def call(message)
            headers = message.headers
            encryption = headers['encryption']
            fingerprint = headers['encryption_fingerprint']

            return super unless active && encryption

            # Decrypt raw payload so it can be handled by the default parser logic
            decrypted_payload = cipher.decrypt(
              encryption,
              message.raw_payload
            )

            message.raw_payload = decrypted_payload

            return super unless fingerprint && fingerprinter

            message_fingerprint = fingerprinter.hexdigest(decrypted_payload)

            return super if message_fingerprint == fingerprint

            raise(Errors::FingerprintVerificationError, message.to_s)
          end
        end
      end
    end
  end
end
