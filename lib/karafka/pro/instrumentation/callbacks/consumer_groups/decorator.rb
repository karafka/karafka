# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# The author retains all right, title, and interest in this software,
# including all copyrights, patents, and other intellectual property rights.
# No patent rights are granted under this license.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Reverse engineering, decompilation, or disassembly of this software
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# Receipt, viewing, or possession of this software does not convey or
# imply any license or right beyond those expressly stated above.
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

module Karafka
  module Pro
    module Instrumentation
      # Namespace for Pro instrumentation callbacks related components
      module Callbacks
        # Namespace for Pro consumer groups callbacks related components
        module ConsumerGroups
          # Pro statistics decorator for consumer groups. On top of the standard decoration
          # (deltas, freeze durations) it invokes Pro statistics enrichments, each encapsulated
          # in its own component with a `#call` entrypoint. Currently: the lag compensation of
          # long-paused partitions.
          class Decorator < Karafka::Instrumentation::Callbacks::ConsumerGroups::Decorator
            def initialize
              super
              @lag_compensator = Pro::Instrumentation::ConsumerGroups::LagCompensation::Compensator.new
            end

            # @param statistics [Hash] raw librdkafka statistics
            # @return [Hash] decorated statistics with the Pro enrichments applied
            #
            # @note When the lag compensation is disabled, its refresher is not subscribed and
            #   the registry stays empty, so the compensation is a pass-through by itself
            def call(statistics)
              @lag_compensator.call(statistics)

              super
            end
          end
        end
      end
    end
  end
end
