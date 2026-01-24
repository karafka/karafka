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
        class Filtering < Base
          # Filtering feature configuration
          Config = Struct.new(:factories, keyword_init: true) do
            # @return [Boolean] is this feature in use. Are any filters defined
            def active?
              !factories.empty?
            end

            # @return [Array<Object>] array of filters applicable to a topic partition
            def filters
              factories.map(&:call)
            end

            # @return [Hash] this config hash
            def to_h
              super.merge(active: active?)
            end
          end
        end
      end
    end
  end
end
