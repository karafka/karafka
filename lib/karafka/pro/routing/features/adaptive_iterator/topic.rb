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
        class AdaptiveIterator < Base
          # Topic extension allowing us to enable and configure adaptive iterator
          module Topic
            # This method calls the parent class initializer and then sets up the
            # extra instance variable to nil. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              super
              @adaptive_iterator = nil
            end

            # @param active [Boolean] should we use the automatic adaptive iterator
            # @param safety_margin [Integer]
            #   How big of a margin we leave ourselves so we can safely communicate back with
            #   Kafka, etc. We stop and seek back when we've burned 85% of the time by default.
            #   We leave 15% of time for post-processing operations so we have space before we
            #   hit max.poll.interval.ms.
            # @param marking_method [Symbol] If we should, how should we mark
            # @param clean_after_yielding [Boolean]  Should we clean post-yielding via the
            #   cleaner API
            def adaptive_iterator(
              active: false,
              safety_margin: 10,
              marking_method: :mark_as_consumed,
              clean_after_yielding: true
            )
              @adaptive_iterator ||= Config.new(
                active: active,
                safety_margin: safety_margin,
                marking_method: marking_method,
                clean_after_yielding: clean_after_yielding
              )
            end

            # @return [Boolean] Is adaptive iterator active. It is always `true`, since we use it
            #   via explicit messages batch wrapper
            def adaptive_iterator?
              adaptive_iterator.active?
            end

            # @return [Hash] topic with all its native configuration options plus poll guarding
            #   setup configuration.
            def to_h
              super.merge(
                adaptive_iterator: adaptive_iterator.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
