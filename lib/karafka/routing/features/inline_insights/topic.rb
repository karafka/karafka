# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class InlineInsights < Base
        module Topic
          def inline_insights(active = false)
            @inline_insights ||= Config.new(
              active: active
            )
          end

          def inline_insights?
            inline_insights.active?
          end

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
