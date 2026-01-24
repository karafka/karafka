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
        class Throttling < Base
          # Topic throttling API extensions
          module Topic
            # This method calls the parent class initializer and then sets up the
            # extra instance variable to nil. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              super
              @throttling = nil
            end

            # @param limit [Integer] max messages to process in an time interval
            # @param interval [Integer] time interval for processing
            def throttling(
              limit: Float::INFINITY,
              interval: 60_000
            )
              # Those settings are used for validation
              @throttling ||= begin
                config = Config.new(
                  active: limit != Float::INFINITY,
                  limit: limit,
                  interval: interval
                )

                # If someone defined throttling setup, we need to create appropriate filter for it
                # and inject it via filtering feature
                if config.active?
                  factory = ->(*) { Pro::Processing::Filters::Throttler.new(limit, interval) }
                  filter(factory)
                end

                config
              end
            end

            # Just an alias for nice API
            #
            # @param args [Hash] Anything `#throttling` accepts
            # @option args [Integer] :limit max messages to process in a time interval
            # @option args [Integer] :interval time interval for processing in milliseconds
            def throttle(**args)
              throttling(**args)
            end

            # @return [Boolean] is a given job throttled
            def throttling?
              throttling.active?
            end

            # @return [Hash] topic with all its native configuration options plus throttling
            def to_h
              super.merge(
                throttling: throttling.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
