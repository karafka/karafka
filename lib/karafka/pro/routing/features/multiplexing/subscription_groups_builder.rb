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
        class Multiplexing < Base
          # Expands the builder to multiply multiplexed groups
          module SubscriptionGroupsBuilder
            # Takes into consideration multiplexing and builds the more groups
            #
            # @param topics_array [Array<Routing::Topic>] group of topics that have the same
            #   settings and can use the same connection
            # @return [Array<Array<Routing::Topics>>] expanded groups
            def expand(topics_array)
              factor = topics_array.first.subscription_group_details.fetch(:multiplexing_max, 1)

              Array.new(factor) do |i|
                Karafka::Routing::Topics.new(
                  i.zero? ? topics_array : topics_array.map(&:dup)
                )
              end
            end
          end
        end
      end
    end
  end
end
