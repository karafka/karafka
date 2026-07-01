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
    module Processing
      module ConsumerGroups
        module Filters
          # Single source of truth for the post-filtering actions. Exposes each action as a method
          # (so filters and internal code can return `Actions.pause` instead of the raw `:pause`
          # symbol), the full `ALL` list, and the `#skip?` / `#pause?` / `#seek?` predicate helpers
          # built on top of `#action`. The predicates are mixed into both individual filters
          # (`Filters::Base`) and the aggregating `Coordinators::FiltersApplier`, so both expose the
          # same API instead of comparing the `#action` symbol directly. The returned values are the
          # plain symbols, so filters that still return `:skip`/`:pause`/`:seek` directly keep
          # working.
          module Actions
            class << self
              # @return [Symbol] the filter did not alter the consumption flow
              def skip
                :skip
              end

              # @return [Symbol] back off the partition and continue later
              def pause
                :pause
              end

              # @return [Symbol] move the partition offset without pausing
              def seek
                :seek
              end
            end

            # All the actions a filter's `#action` (or the aggregated applier `#action`) can return
            ALL = [skip, pause, seek].freeze

            # @return [Boolean] should we skip without pausing or seeking
            def skip?
              action == Actions.skip
            end

            # @return [Boolean] should we pause the partition
            def pause?
              action == Actions.pause
            end

            # @return [Boolean] should we seek the partition
            def seek?
              action == Actions.seek
            end
          end
        end
      end
    end
  end
end
