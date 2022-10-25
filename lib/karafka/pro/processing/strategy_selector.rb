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
      class StrategySelector
        def initialize
          # We load them once for performance reasons not to do too many lookups
          @available_strategies = Strategies
                                  .constants
                                  .delete_if { |k| k == :Base }
                                  .map { |k| Strategies.const_get(k) }
        end

        # @param topic [Karafka::Routing::Topic] topic with settings based on which we find
        #   strategy
        # @return [Module] module with proper strategy
        def find(topic)
          # ActiveJob usage is not a feature that would impact the strategy. ActiveJob always goes
          # with manual offset management.
          combo = [
            topic.active_job? ? :active_job : nil,
            topic.manual_offset_management? ? :manual_offset_management : nil
          ].compact

          @available_strategies.find do |strategy|
            strategy::FEATURES == combo
          end || raise(Errors::StrategyNotFoundError, topic.name)
        end
      end
    end
  end
end
