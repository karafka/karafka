# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class InlineInsights < Base
        module Topic
          def inline_statistics(active = false)
            @inline_statistics ||= Config.new(
              active: active
            )
          end

          def inline_statistics?
            inline_statistics.active?
          end

          def to_h
            super.merge(
              inline_statistics: inline_statistics.to_h
            ).freeze
          end
        end
      end
    end
  end
end
