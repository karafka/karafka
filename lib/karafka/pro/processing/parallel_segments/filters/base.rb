# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module ParallelSegments
        # Module for filters injected into the processing pipeline of each of the topics used
        # within the parallel segmented consumer groups
        module Filters
          # Base class for filters for parallel segments that deal with different feature scenarios
          class Base < Processing::Filters::Base
            # @param segment_id [Integer] numeric id of the parallel segment group to use with the
            #   partitioner and reducer for segment matching comparison
            # @param partitioner [Proc]
            # @param reducer [Proc]
            def initialize(segment_id:, partitioner:, reducer:)
              super()

              @segment_id = segment_id
              @partitioner = partitioner
              @reducer = reducer
            end
          end
        end
      end
    end
  end
end
