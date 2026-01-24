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
        class Delaying < Base
          # Topic delaying API extensions
          module Topic
            # This method calls the parent class initializer and then sets up the
            # extra instance variable to nil. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              super
              @delaying = nil
            end

            # @param delay [Integer, nil] minimum age of a message we want to process
            def delaying(delay = nil)
              # Those settings are used for validation
              @delaying ||= begin
                config = Config.new(active: !delay.nil?, delay: delay)

                if config.active?
                  factory = ->(*) { Pro::Processing::Filters::Delayer.new(delay) }
                  filter(factory)
                end

                config
              end
            end

            # Just an alias for nice API
            def delay_by(*)
              delaying(*)
            end

            # @return [Boolean] is a given job delaying
            def delaying?
              delaying.active?
            end

            # @return [Hash] topic with all its native configuration options plus delaying
            def to_h
              super.merge(
                delaying: delaying.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
