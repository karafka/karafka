# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class InlineInsights < Base
        # Routing topic inline insights API
        module Topic
          # This method calls the parent class initializer and then sets up the
          # extra instance variable to nil. The explicit initialization
          # to nil is included as an optimization for Ruby's object shapes system,
          # which improves memory layout and access performance.
          def initialize(...)
            super
            @inline_insights = nil
          end

          # @param active [Boolean] should inline insights be activated
          def inline_insights(active = false)
            @inline_insights ||= Config.new(
              active: active
            )
          end

          # @return [Boolean] Are inline insights active
          def inline_insights?
            inline_insights.active?
          end

          # @return [Hash] topic setup hash
          def to_h
            super.merge(
              inline_insights: inline_insights.to_h
            ).freeze
          end
        end
      end
    end
  end
end
