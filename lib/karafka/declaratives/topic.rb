# frozen_string_literal: true

module Karafka
  module Declaratives
    # Represents a single declarative topic definition — what a topic should look like on the
    # broker. This is a standalone object, independent of routing concepts like consumers or
    # subscription groups.
    class Topic
      attr_reader :name, :details
      attr_writer :active, :partitions, :replication_factor, :details

      # @param name [String, Symbol] topic name
      def initialize(name)
        @name = name.to_s
        @active = true
        @partitions = 1
        @replication_factor = 1
        @details = {}
      end

      # Gets or sets the active flag
      # @param value [Symbol, Boolean] when :not_set returns current value, otherwise sets it
      # @return [Boolean] active state
      def active(value = :not_set)
        if value == :not_set
          @active
        else
          @active = value
        end
      end

      # @return [Boolean] is this topic actively managed via declaratives
      def active?
        @active
      end

      # Gets or sets the partition count
      # @param value [Symbol, Integer] when :not_set returns current value, otherwise sets it
      # @return [Integer] partition count
      def partitions(value = :not_set)
        if value == :not_set
          @partitions
        else
          @partitions = value
        end
      end

      # Gets or sets the replication factor
      # @param value [Symbol, Integer] when :not_set returns current value, otherwise sets it
      # @return [Integer] replication factor
      def replication_factor(value = :not_set)
        if value == :not_set
          @replication_factor
        else
          @replication_factor = value
        end
      end

      # Merges Kafka topic configuration entries into the details hash
      # @param entries [Hash] topic config entries like 'retention.ms' => 604_800_000
      def config(entries = {})
        @details.merge!(entries.transform_keys(&:to_sym))
      end

      # @return [Hash] hash representation matching the old Config struct's to_h output
      def to_h
        {
          active: @active,
          partitions: @partitions,
          replication_factor: @replication_factor,
          details: @details
        }
      end
    end
  end
end
