# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module ScheduledMessages
      # Proxy used to wrap the scheduled messages with the correct dispatch envelope.
      # Each message that goes to the scheduler topic needs to have specific headers and other
      # details that are required by the system so we know how and when to dispatch it.
      #
      # Each message that goes to the proxy topic needs to have a unique key. We inject those
      # automatically unless user provides one in an envelope. Since we want to make sure, that
      # the messages dispatched by the user all go to the same partition (if with same key), we
      # inject a partition_key based on the user key or other details if present. That allows us
      # to make sure, that they will always go to the same partition on our side.
      #
      # This wrapper validates the initial message that user wants to send in the future, as well
      # as the envelope and specific requirements for a message to be send in the future
      module Proxy
        # General WaterDrop message contract. Before we envelop a message, we need to be certain
        # it is correct, hence we use this contract.
        MSG_CONTRACT = ::WaterDrop::Contracts::Message.new(
          # Payload size is a subject to the target producer dispatch validation, so we set it
          # to 100MB basically to ignore it here.
          max_payload_size: 104_857_600
        )

        # Post-rebind contract to ensure, that user provided all needed details that would allow
        # the system to operate correctly
        POST_CONTRACT = Contracts::Message.new

        # Attributes used to build a partition key for the schedules topic dispatch of a given
        # message. We use this order as this order describes the priority of usage.
        PARTITION_KEY_BASE_ATTRIBUTES = %i[
          partition
          partition_key
        ].freeze

        private_constant :MSG_CONTRACT, :POST_CONTRACT, :PARTITION_KEY_BASE_ATTRIBUTES

        class << self
          # Generates a schedule message envelope wrapping the original dispatch
          #
          # @param message [Hash] message hash of a message that would originally go to WaterDrop
          #   producer directly.
          # @param epoch [Integer] time in the future (or now) when dispatch this message in the
          #   Unix epoch timestamp
          # @param envelope [Hash] Special details that the envelop needs to have, like a unique
          #   key. If unique key is not provided we build a random unique one and use a
          #   partition_key based on the original message key (if present) to ensure that all
          #   relevant messages are dispatched to the same topic partition.
          # @return [Hash] dispatched message wrapped with an envelope
          #
          # @note This proxy does **not** inject the dispatched messages topic unless provided in
          #   the envelope. That's because user can have multiple scheduled messages topics to
          #   group outgoing messages, etc.
          def schedule(message:, epoch:, envelope: {})
            # We need to ensure that the message we want to proxy is fully legit. Otherwise, since
            # we envelope details like target topic, we could end up having incorrect data to
            # schedule
            MSG_CONTRACT.validate!(
              message,
              WaterDrop::Errors::MessageInvalidError,
              scope: %w[scheduled_messages message]
            )

            headers = (message[:headers] || {}).merge(
              'schedule_schema_version' => ScheduledMessages::SCHEMA_VERSION,
              'schedule_target_epoch' => epoch.to_i.to_s,
              'schedule_source_type' => 'schedule'
            )

            export(headers, message, :topic)
            export(headers, message, :partition)
            export(headers, message, :key)
            export(headers, message, :partition_key)

            proxy_message = {
              payload: message[:payload],
              headers: headers
            }.merge(envelope)

            enrich(proxy_message, message)
            validate!(proxy_message)

            proxy_message
          end

          # Generates a tombstone message to cancel already scheduled message dispatch
          # @param key [String] key used by the original message as a unique identifier
          # @param envelope [Hash] Special details that can identify the message location like
          #   topic and partition (if used) so the cancellation goes to the correct location.
          # @return [Hash] cancellation message
          #
          # @note Technically it is a tombstone but we differentiate just for the sake of ability
          #   to debug stuff if needed
          def cancel(key:, envelope: {})
            proxy_message = {
              key: key,
              payload: nil,
              headers: {
                'schedule_schema_version' => ScheduledMessages::SCHEMA_VERSION,
                'schedule_source_type' => 'cancel'
              }
            }.merge(envelope)

            # Ensure user provided envelope is with all expected details
            validate!(proxy_message)

            proxy_message
          end

          # Builds tombstone with the dispatched message details. Those details can be used
          #   in Web UI, etc when analyzing dispatches.
          # @param message [Karafka::Messages::Message] message we want to tombstone
          #   topic and partition (if used) so the cancellation goes to the correct location.
          def tombstone(message:)
            {
              key: message.key,
              payload: nil,
              topic: message.topic,
              partition: message.partition,
              headers: message.raw_headers.merge(
                'schedule_schema_version' => ScheduledMessages::SCHEMA_VERSION,
                'schedule_source_type' => 'tombstone',
                'schedule_source_offset' => message.offset.to_s
              )
            }
          end

          private

          # Transfers the message key attributes into headers. Since we need to have our own
          # envelope key and other details, we transfer the original message details into headers
          # so we can re-use them when we dispatch the scheduled messages at an appropriate time
          #
          # @param headers [Hash] envelope headers to which we will add appropriate attribute
          # @param message [Hash] original user message
          # @param attribute [Symbol] attribute we're interested in exporting to headers
          # @note Modifies headers in place
          def export(headers, message, attribute)
            return unless message.key?(attribute)

            headers["schedule_target_#{attribute}"] = message.fetch(attribute).to_s
          end

          # Adds the key and (if applicable) partition key to ensure, that related messages that
          # user wants to dispatch in the future, are all in the same topic partition.
          # @param proxy_message [Hash] our message envelope
          # @param message [Hash] user original message
          # @note Modifies `proxy_message` in place
          def enrich(proxy_message, message)
            # If there is an envelope message key already, nothing needed
            return if proxy_message.key?(:key)

            proxy_message[:key] = "#{message[:topic]}-#{SecureRandom.uuid}"

            PARTITION_KEY_BASE_ATTRIBUTES.each do |attribute|
              next unless message.key?(attribute)
              # Do not overwrite if explicitely set by the user
              next if proxy_message.key?(attribute)

              proxy_message[:partition_key] = message.fetch(attribute).to_s
            end
          end

          # Final validations to make sure all user provided extra data and what we have built
          # complies with our requirements
          # @param proxy_message [Hash] our message envelope
          def validate!(proxy_message)
            POST_CONTRACT.validate!(
              proxy_message,
              scope: %w[scheduled_messages message]
            )

            # After proxy specific validations we also ensure, that the final form is correct
            MSG_CONTRACT.validate!(
              proxy_message,
              WaterDrop::Errors::MessageInvalidError,
              scope: %w[scheduled_messages message]
            )
          end
        end
      end
    end
  end
end
