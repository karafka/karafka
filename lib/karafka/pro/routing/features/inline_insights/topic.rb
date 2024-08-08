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
    module Routing
      module Features
        class InlineInsights < Base
          # Routing topic inline insights API
          module Topic
            # @param active [Boolean] should inline insights be activated
            # @param required [Boolean] are the insights required to operate
            def inline_insights(active = Karafka::Routing::Default.new(false),
                                required: Karafka::Routing::Default.new(false))
              # This weird style of checking allows us to activate inline insights in few ways:
              #   - inline_insights(true)
              #   - inline_insights(required: true)
              #   - inline_insights(required: false)
              #
              # In each of those cases inline insights will become active
              @inline_insights ||= Config.new(active: active, required: required)
              return @inline_insights if Config.all_defaults?(active, required)

              begin
                @inline_insights.active = active == true ||
                  (active.is_a?(Karafka::Routing::Default) && !required.is_a?(Karafka::Routing::Default))
                @inline_insights.required = required == true

                if @inline_insights.active? && @inline_insights.required?
                  factory = lambda do |topic, partition|
                    Pro::Processing::Filters::InlineInsightsDelayer.new(topic, partition)
                  end

                  filter(factory)
                end

                @inline_insights
              end
            end
          end
        end
      end
    end
  end
end
