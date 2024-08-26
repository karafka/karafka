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
      class Dispatcher
        def initialize
          @buffer = []
        end

        def buffer(message)
          base_headers = message.raw_headers.merge(
            'future_source_topic': message.topic,
            'future_source_partition': message.partition,
            'future_source_offset': message.offset
          )

          base = {
            payload: message.raw_payload,
            topic: message.raw_headers['future_target_topic'],
            headers: base_headers
          }

          base_headers['future_source_key'] = message.key if message.key

          if message.headers['future_target_partition']
            base[:partition] = message.headers['future_target_partition']
          end

          if message.headers['future_target_key']
            base[:key] = message.headers['future_target_key']
          end

          if message.headers['future_target_partition_key']
            base[:partition_key] = message.headers['future_target_partition_key']
          end

          @buffer << base

          @buffer << {
            topic: message.topic,
            partition: message.partition,
            key: message.key,
            payload: nil
          }

          @buffer << base
        end
      end
    end
  end
end
