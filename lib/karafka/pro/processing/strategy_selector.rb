# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      # Selector of appropriate processing strategy matching topic combinations
      # When using Karafka Pro, there is a different set of strategies than for regular, as there
      # are different features.
      class StrategySelector
        attr_reader :strategies

        # Strategies that we support in the Pro offering
        # They can be combined
        SUPPORTED_FEATURES = %i[
          active_job
          long_running_job
          manual_offset_management
          virtual_partitions
          dead_letter_queue
          filtering
        ].freeze

        def initialize
          # Preload the strategies
          # We load them once for performance reasons not to do too many lookups
          @strategies = find_all
        end

        # @param topic [Karafka::Routing::Topic] topic with settings based on which we find
        #   the strategy
        # @return [Module] module with proper strategy
        def find(topic)
          feature_set = SUPPORTED_FEATURES.map do |feature_name|
            topic.public_send("#{feature_name}?") ? feature_name : nil
          end

          feature_set.compact!
          feature_set.sort!

          @strategies.find do |strategy|
            strategy::FEATURES.sort == feature_set
          end || raise(Errors::StrategyNotFoundError, topic.name)
        end

        private

        # @return [Array<Module>] all available strategies
        def find_all
          scopes = [Strategies]
          modules = Strategies.constants

          modules.each do |const|
            scopes << Strategies.const_get(const)
            modules += scopes.last.constants
          end

          scopes.flat_map do |scope|
            modules.map do |const|
              next if const == :FEATURES
              next unless scope.const_defined?(const)

              candidate = scope.const_get(const)

              next unless candidate.const_defined?(:FEATURES)

              candidate
            end
          end.uniq.compact
        end
      end
    end
  end
end
