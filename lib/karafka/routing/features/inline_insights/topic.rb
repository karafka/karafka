# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class InlineInsights < Base
        # Routing topic inline insights API
        module Topic
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
