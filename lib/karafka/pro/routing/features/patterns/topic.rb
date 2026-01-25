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
        class Patterns < Base
          # Patterns feature topic extensions
          module Topic
            # This method calls the parent class initializer and then sets up the
            # extra instance variable to nil. The explicit initialization
            # to nil is included as an optimization for Ruby's object shapes system,
            # which improves memory layout and access performance.
            def initialize(...)
              super
              @patterns = nil
            end

            # @return [String] subscription name or the regexp string representing matching of
            #   new topics that should be detected.
            def subscription_name
              (patterns.active? && patterns.matcher?) ? patterns.pattern.regexp_string : super
            end

            # @param active [Boolean] is this topic active member of patterns
            # @param type [Symbol] type of topic taking part in pattern matching
            # @param pattern [Regexp] regular expression for matching
            def patterns(active: false, type: :regular, pattern: nil)
              @patterns ||= Config.new(active: active, type: type, pattern: pattern)
            end

            # @return [Boolean] is this topic a member of patterns
            def patterns?
              patterns.active?
            end

            # @return [Hash] topic with all its native configuration options plus patterns
            def to_h
              super.merge(
                patterns: patterns.to_h
              ).freeze
            end
          end
        end
      end
    end
  end
end
