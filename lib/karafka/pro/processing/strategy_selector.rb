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
    module Processing
      # Selector of appropriate processing strategy matching topic combinations
      # When using Karafka Pro, there is a different set of strategies than for regular, as there
      # are different features.
      class StrategySelector
        def initialize
          # We load them once for performance reasons not to do too many lookups
          @available_strategies = Strategies
                                  .constants
                                  .delete_if { |k| k == :Base }
                                  .map { |k| Strategies.const_get(k) }
        end

        # @param topic [Karafka::Routing::Topic] topic with settings based on which we find
        #   the strategy
        # @return [Module] module with proper strategy
        def find(topic)
          feature_set = features_map(topic)

          @available_strategies.find do |strategy|
            strategy::FEATURES.sort == feature_set
          end || raise(Errors::StrategyNotFoundError, topic.name)
        end

        private

        # Builds features map used to find matching processing strategy
        #
        # @param topic [Karafka::Routing::Topic]
        # @return [Array<Symbol>]
        def features_map(topic)
          [
            topic.active_job? ? :active_job : nil,
            topic.long_running_job? ? :long_running_job : nil,
            topic.manual_offset_management? ? :manual_offset_management : nil,
            topic.virtual_partitions? ? :virtual_partitions : nil
          ].compact.sort
        end
      end
    end
  end
end
