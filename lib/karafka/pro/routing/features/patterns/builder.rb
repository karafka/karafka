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
          # Expansions for the routing builder
          module Builder
            # Allows us to define the simple routing pattern matching
            #
            # @param regexp_or_name [Symbol, String, Regexp] name of the pattern or regexp for
            #   automatic-based named patterns
            # @param regexp [Regexp, nil] nil if we use auto-generated name based on the regexp or
            #   the regexp if we used named patterns
            # @param block [Proc]
            def pattern(regexp_or_name, regexp = nil, &block)
              consumer_group(default_group_id) do
                pattern(regexp_or_name, regexp, &block)
              end
            end
          end
        end
      end
    end
  end
end
