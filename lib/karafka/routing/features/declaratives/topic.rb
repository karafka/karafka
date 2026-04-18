# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Declaratives < Base
        # Bridge module prepended onto Karafka::Routing::Topic.
        # The config(...) method forwards to the Declaratives subsystem, creating or retrieving
        # a Karafka::Declaratives::Topic in the repository. This preserves backwards compatibility
        # while the actual declarative state lives in Karafka::Declaratives.
        module Topic
          # This method sets up the extra instance variable to nil before calling
          # the parent class initializer. The explicit initialization
          # to nil is included as an optimization for Ruby's object shapes system,
          # which improves memory layout and access performance.
          def initialize(...)
            @declaratives = nil
            super
          end

          # Bridge: creates/retrieves a Declaratives::Topic in the repository and returns it.
          # Preserves the ||= semantics (first call wins) for backwards compatibility.
          #
          # @param active [Boolean] is the topic structure management feature active
          # @param partitions [Integer] number of partitions for the topic
          # @param replication_factor [Integer] replication factor for the topic
          # @param details [Hash] extra configuration for the topic
          # @option details [String] :retention.ms retention time in milliseconds
          # @option details [String] :compression.type compression type
          #   (none, gzip, snappy, lz4, zstd)
          # @return [Karafka::Declaratives::Topic] the declarative topic
          def config(active: true, partitions: 1, replication_factor: 1, **details)
            @declaratives ||= Karafka::App.declaratives.repository.find_or_create_if_new(name) do |declaration|
              declaration.active(active)
              declaration.partitions(partitions)
              declaration.replication_factor(replication_factor)
              declaration.config(details) unless details.empty?
            end
          end

          # @return [Karafka::Declaratives::Topic] config details
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
