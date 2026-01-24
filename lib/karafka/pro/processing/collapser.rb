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
      # Manages the collapse of virtual partitions
      # Since any non-virtual partition is actually a virtual partition of size one, we can use
      # it in a generic manner without having to distinguish between those cases.
      #
      # We need to have notion of the offset until we want to collapse because upon pause and retry
      # rdkafka may purge the buffer. This means, that we may end up with smaller or bigger
      # (different) dataset and without tracking the end of collapse, there would be a chance for
      # things to flicker. Tracking allows us to ensure, that collapse is happening until all the
      # messages from the corrupted batch are processed.
      class Collapser
        # When initialized, nothing is collapsed
        def initialize
          @collapsed = false
          @until_offset = -1
          @mutex = Mutex.new
        end

        # @return [Boolean] Should we collapse into a single consumer
        def collapsed?
          @collapsed
        end

        # Collapse until given offset. Until given offset is encountered or offset bigger than that
        # we keep collapsing.
        # @param offset [Integer] offset until which we keep the collapse
        def collapse_until!(offset)
          @mutex.synchronize do
            # We check it here in case after a pause and re-fetch we would get less messages and
            # one of them would cause an error. We do not want to overwrite the offset here unless
            # it is bigger.
            @until_offset = offset if offset > @until_offset
          end
        end

        # Sets the collapse state based on the first collective offset that we are going to process
        # and makes the decision whether or not we need to still keep the collapse.
        # @param first_offset [Integer] first offset from a collective batch
        def refresh!(first_offset)
          @mutex.synchronize do
            @collapsed = first_offset < @until_offset
          end
        end
      end
    end
  end
end
