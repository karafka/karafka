# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
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
