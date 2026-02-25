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
      # Namespace for schedules data related deserializers.
      module Deserializers
        # Converts certain pieces of headers into their integer form for messages
        class Headers
          # We only directly operate on epoch and other details for schedules and tombstones.
          # cancel requests don't have to be deserialized that way since they don't have epoch
          WORKABLE_TYPES = %w[schedule tombstone].freeze

          private_constant :WORKABLE_TYPES

          # @param metadata [Karafka::Messages::Metadata]
          # @return [Hash] headers
          def call(metadata)
            raw_headers = metadata.raw_headers

            type = raw_headers.fetch("schedule_source_type")

            # tombstone and cancellation events are not operable, thus we do not have to cast any
            # of the headers pieces
            return raw_headers unless WORKABLE_TYPES.include?(type)

            headers = raw_headers.dup
            headers["schedule_target_epoch"] = headers["schedule_target_epoch"].to_i

            # This attribute is optional, this is why we have to check for its existence
            if headers.key?("schedule_target_partition")
              headers["schedule_target_partition"] = headers["schedule_target_partition"].to_i
            end

            headers
          end
        end
      end
    end
  end
end
