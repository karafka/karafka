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
      module Deserializers
        class Headers
          def call(metadata)
            raw_headers = metadata.raw_headers

            type = raw_headers.fetch('future_type')

            case type
            when 'recovery'
              raw_headers
            when 'tombstone'
              raw_headers
            when 'message'
              headers = raw_headers.dup
              headers['future_target_epoch'] = headers['future_target_epoch'].to_i
              headers['future_target_partition'] = headers['future_target_partition'].to_i if headers.key?('future_target_partition')
              headers
            else
              raise Karafka::Errors::UnsupportedCaseError, type
            end
          end
        end
      end
    end
  end
end
