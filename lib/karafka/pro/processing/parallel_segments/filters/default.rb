# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      # Processing components namespace for parallel segments feature
      module ParallelSegments
        module Filters
          # Filter used for handling parallel segments with automatic offset management. Handles
          # message distribution and ensures proper offset management when messages are filtered
          # out during the distribution process.
          #
          # When operating in automatic offset management mode, this filter takes care of marking
          # offsets of messages that were filtered out during the distribution process to maintain
          # proper offset progression.
          #
          # @note This is the default filter that should be used when manual offset management
          #   is not enabled. For manual offset management scenarios use the Mom filter instead.
          class Default < Base
          end
        end
      end
    end
  end
end
