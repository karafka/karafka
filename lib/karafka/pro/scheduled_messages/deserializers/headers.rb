# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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

          # @param metadata [Karafka::aMessages::Metadata]
          # @return [Hash] headers
          def call(metadata)
            raw_headers = metadata.raw_headers

            type = raw_headers.fetch('schedule_source_type')

            # tombstone and cancellation events are not operable, thus we do not have to cast any
            # of the headers pieces
            return raw_headers unless WORKABLE_TYPES.include?(type)

            headers = raw_headers.dup
            headers['schedule_target_epoch'] = headers['schedule_target_epoch'].to_i

            # This attribute is optional, this is why we have to check for its existence
            if headers.key?('schedule_target_partition')
              headers['schedule_target_partition'] = headers['schedule_target_partition'].to_i
            end

            headers
          end
        end
      end
    end
  end
end
