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
    module ScheduledMessages
      # Serializers used to build payloads (if applicable) for dispatch
      # @note We only deal with states payload. Other payloads are not ours but end users.
      class Serializer
        include Karafka::Core::Helpers::Time

        # @param tracker [Tracker] tracker based on which we build the state
        # @return [String] compressed payload with the state details
        def state(tracker)
          data = {
            schema_version: ScheduledMessages::STATES_SCHEMA_VERSION,
            dispatched_at: float_now
          }.merge(tracker.to_h)

          compress(
            serialize(data)
          )
        end

        private

        # @param hash [Hash] hash to cast to json
        # @return [String] json hash
        def serialize(hash)
          hash.to_json
        end

        # Compresses the provided data using Zlib deflate algorithm
        #
        # @param data [String]
        # @return [String] compressed data
        def compress(data)
          Zlib::Deflate.deflate(data)
        end
      end
    end
  end
end
