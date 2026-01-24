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
        # Holds pattern info reference
        # Type is set to:
        #   `:regular` - in case patterns are not used and topic is just a regular existing topic
        #                matched directly based on the name
        #   `:discovered` - in case it is a real topic on which we started to listed
        #   `:matcher` - represents a regular expression used by librdkafka
        class Patterns < Base
          # Config for pattern based topic
          # Only pattern related topics are active in this context
          Config = Struct.new(
            :active,
            :type,
            :pattern,
            keyword_init: true
          ) do
            alias_method :active?, :active

            # @return [Boolean] is this a matcher topic
            def matcher?
              type == :matcher
            end

            # @return [Boolean] is this a discovered topic
            def discovered?
              type == :discovered
            end

            # @return [Boolean] is this a regular topic
            def regular?
              type == :regular
            end
          end
        end
      end
    end
  end
end
