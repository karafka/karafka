# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Structurable < Base
        # Extension for managing Kafka topic configuration
        module Topic
          # @param partition_count [Integer]
          # @param replication_factor [Integer]
          # @param details [Hash] extra configuration for the topic
          # @return [Config] defined structure
          def config(partition_count: 1, replication_factor: 1, **details)
            @structurable ||= Config.new(
              active: true,
              partition_count: partition_count,
              replication_factor: replication_factor,
              details: details
            )
          end

          # @return [Config] config details
          def structurable
            config
          end

          # @return [true] structurable is always active
          def structurable?
            structurable.active?
          end

          # @return [Hash] topic with all its native configuration options plus structurable
          #   settings
          def to_h
            super.merge(
              structurable: structurable.to_h
            ).freeze
          end
        end
      end
    end
  end
end
