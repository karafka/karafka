# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Declaratives < Base
        # Extension for managing Kafka topic configuration
        module Topic
          # This method calls the parent class initializer and then sets up the
          # extra instance variable to nil. The explicit initialization
          # to nil is included as an optimization for Ruby's object shapes system,
          # which improves memory layout and access performance.
          def initialize(...)
            super
            @declaratives = nil
          end

          # @param active [Boolean] is the topic structure management feature active
          # @param partitions [Integer] number of partitions for the topic
          # @param replication_factor [Integer] replication factor for the topic
          # @param details [Hash] extra configuration for the topic
          # @option details [String] :retention.ms retention time in milliseconds
          # @option details [String] :compression.type compression type
          #   (none, gzip, snappy, lz4, zstd)
          # @return [Config] defined structure
          def config(active: true, partitions: 1, replication_factor: 1, **details)
            @declaratives ||= Config.new(
              active: active,
              partitions: partitions,
              replication_factor: replication_factor,
              details: details
            )
          end

          # @return [Config] config details
          def declaratives
            config
          end

          # @return [true] declaratives is always active
          def declaratives?
            declaratives.active?
          end

          # @return [Hash] topic with all its native configuration options plus declaratives
          #   settings
          def to_h
            super.merge(
              declaratives: declaratives.to_h
            ).freeze
          end
        end
      end
    end
  end
end
