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
    module Processing
      module Filters
        # Delayer that checks if we have appropriate insights available. If not, pauses for
        # 5 seconds so the insights can be loaded from the broker.
        #
        # In case it would take more than five seconds to load insights, it will just pause again
        #
        # This filter ensures, that we always have inline insights that a consumer can use
        #
        # It is relevant in most cases only during the process start, when first poll may not
        # yield statistics yet but will give some data.
        class InlineInsightsDelayer < Base
          # Minimum how long should we pause when there are no metrics
          PAUSE_TIMEOUT = 5_000

          private_constant :PAUSE_TIMEOUT

          # @param topic [Karafka::Routing::Topic]
          # @param partition [Integer] partition
          def initialize(topic, partition)
            super()
            @topic = topic
            @partition = partition
          end

          # Pauses if inline insights would not be available. Does nothing otherwise
          #
          # @param messages [Array<Karafka::Messages::Message>]
          def apply!(messages)
            @applied = false
            @cursor = messages.first

            # Nothing to do if there were no messages
            # This can happen when we chain filters
            return unless @cursor

            insights = Karafka::Processing::InlineInsights::Tracker.find(
              @topic,
              @partition
            )

            # If insights are available, also nothing to do here and we can just process
            return unless insights.empty?

            messages.clear

            @applied = true
          end

          # @return [Integer, nil] ms timeout in case of pause or nil if not delaying
          def timeout
            (@cursor && applied?) ? PAUSE_TIMEOUT : nil
          end

          # Pause when we had to back-off or skip if delay is not needed
          def action
            applied? ? :pause : :skip
          end
        end
      end
    end
  end
end
