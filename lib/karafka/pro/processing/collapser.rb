# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
