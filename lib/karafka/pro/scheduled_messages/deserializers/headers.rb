# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    module ScheduledMessages
      # Namespace for schedules data related deserializers.
      module Deserializers
        # Converts certain pieces of headers into their integer form for messages
        class Headers
          # @param metadata [Karafka::aMessages::Metadata]
          # @return [Hash] headers
          def call(metadata)
            raw_headers = metadata.raw_headers

            type = raw_headers.fetch('schedule_source_type')

            # tombstone and cancellation events are not operable, thus we do not have to cast any
            # of the headers pieces
            return raw_headers unless type == 'schedule'

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
