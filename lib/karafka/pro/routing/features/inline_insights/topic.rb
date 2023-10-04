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
            def inline_insights(active = -1, required: -1)
              # This weird style of checking allows us to activate inline insights in few ways:
              #   - inline_insights(true)
              #   - inline_insights(required: true)
              #   - inline_insights(required: false)
              #
              # In each of those cases inline insights will become active
              @inline_insights ||= begin
                config = Config.new(
                  active: active == true || (active == -1 && required != -1),
                  required: required == true
                )

                if config.active? && config.required?
                  factory = lambda do |topic, partition|
                    Pro::Processing::Filters::InlineInsightsDelayer.new(topic, partition)
                  end

                  filter(factory)
                end

                config
              end
            end
          end
        end
      end
    end
  end
end
