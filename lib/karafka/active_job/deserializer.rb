# frozen_string_literal: true

module Karafka
  module ActiveJob
    # Default deserializer for ActiveJob jobs
    #
    # @note Despite the name, this class handles both serialization (job to Kafka payload) and
    #   deserialization (Kafka message to job). It's called "Deserializer" to align with Karafka's
    #   naming conventions where message consumption is the primary concern.
    #
    # This class can be inherited and its methods can be overridden to support
    # custom payload formats (e.g., Avro, Protobuf, MessagePack)
    #
    # @example Wrapping jobs in a custom envelope with metadata
    #   class EnvelopedJobDeserializer < Karafka::ActiveJob::Deserializer
    #     def serialize(job)
    #       # Wrap the job in an envelope with additional metadata
    #       envelope = {
    #         version: 1,
    #         produced_at: Time.now.iso8601,
    #         producer: 'my-app',
    #         payload: job.serialize
    #       }
    #       ::ActiveSupport::JSON.encode(envelope)
    #     end
    #
    #     def deserialize(message)
    #       # Extract the job from the envelope
    #       envelope = ::ActiveSupport::JSON.decode(message.raw_payload)
    #
    #       # Could validate envelope version, log metadata, etc.
    #       raise 'Unsupported version' if envelope['version'] != 1
    #
    #       # Return the actual job data
    #       envelope['payload']
    #     end
    #   end
    #
    #   # Configure in Karafka
    #   Karafka::App.config.internal.active_job.deserializer = EnvelopedJobDeserializer.new
    class Deserializer
      # Serializes an ActiveJob job into a string payload for Kafka
      #
      # @param job [ActiveJob::Base] job to serialize
      # @return [String] serialized job payload
      def serialize(job)
        ::ActiveSupport::JSON.encode(job.serialize)
      end

      # Deserializes a Kafka message payload into an ActiveJob job hash
      #
      # @param message [Karafka::Messages::Message] message containing the job
      # @return [Hash] deserialized job hash
      def deserialize(message)
        ::ActiveSupport::JSON.decode(message.raw_payload)
      end
    end
  end
end
