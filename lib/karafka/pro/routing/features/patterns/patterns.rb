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
          # Representation of groups of topics
          class Patterns < Karafka::Routing::Topics
            # Finds first pattern matching given topic name
            #
            # @param topic_name [String] topic name that may match a pattern
            # @return [Karafka::Routing::Pattern, nil] pattern or nil if not found
            # @note Please keep in mind, that there may be many patterns matching given topic name
            #   and we always pick the first one (defined first)
            def find(topic_name)
              @accumulator.find { |pattern| pattern.regexp =~ topic_name }
            end
          end
        end
      end
    end
  end
end
