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

module Karafka
  module Pro
    module Processing
      module ShareGroups
        # Pro processing strategies for share-group consumers
        module Strategies
          # When using dead letter queue, records that keep failing are moved to a separate topic
          # after a defined number of retries, instead of being redelivered until the broker drops
          # them at the share group delivery count limit. Mirrors
          # {Karafka::Processing::ConsumerGroups::Strategies::Dlq}: retries are counted with the
          # record delivery count instead of the pause tracker.
          module Dlq
            include Karafka::Processing::ShareGroups::Strategies::Default

            # Apply strategy when only dead letter queue is turned on
            FEATURES = %i[
              dead_letter_queue
            ].freeze

            # After a failure, the first record the consumer left unacknowledged is considered the
            # one that broke the processing, same as the first not marked message for consumer
            # groups. Once it was delivered more times than allowed, it is dispatched to the DLQ
            # topic and rejected, so the broker does not deliver it again. The rest is released for
            # another attempt.
            def handle_after_consume
              consumption = coordinator.consumption(self)

              # Process-critical errors are never dispatched to the DLQ regardless of the retries
              # state, same as for consumer groups - the records are redelivered after the restart
              if !consumption.success? && !critical_error?(consumption.cause)
                broken = messages.raw.find do |message|
                  !acknowledgements_tracker.acknowledged?(message)
                end

                if broken && broken.delivery_count > topic.dead_letter_queue.max_retries
                  # The record is gone once rejected, so it has to be dispatched first
                  dispatch_to_dlq(broken) if topic.dead_letter_queue.topic

                  mark_as_rejected(broken)
                end
              end

              super
            end

            # Moves the broken record into a separate queue defined via the settings
            # @private
            # @param message [Karafka::Messages::Message] record that should go to the dlq topic
            def dispatch_to_dlq(message)
              producer.public_send(
                topic.dead_letter_queue.dispatch_method,
                topic: topic.dead_letter_queue.topic,
                payload: message.raw_payload
              )

              # Notify about dispatch on the events bus
              monitor.instrument(
                "dead_letter_queue.dispatched",
                caller: self,
                message: message
              )
            end
          end
        end
      end
    end
  end
end
