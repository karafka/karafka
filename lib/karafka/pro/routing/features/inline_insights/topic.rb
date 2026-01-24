# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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
