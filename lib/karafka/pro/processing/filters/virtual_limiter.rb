# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Processing
      module Filters
        # Removes messages that are already marked as consumed in the virtual offset manager
        # This should operate only when using virtual partitions.
        #
        # This cleaner prevents us from duplicated processing of messages that were virtually
        # marked as consumed even if we could not mark them as consumed in Kafka. This allows us
        # to limit reprocessing when errors occur drastically when operating with virtual
        # partitions
        #
        # @note It should be registered only when VPs are used
        class VirtualLimiter < Base
          # @param manager [Processing::VirtualOffsetManager]
          # @param collapser [Processing::Collapser]
          def initialize(manager, collapser)
            @manager = manager
            @collapser = collapser

            super()
          end

          # Remove messages that we already marked as virtually consumed. Does nothing if not in
          # the collapsed mode.
          #
          # @param messages [Array<Karafka::Messages::Message>]
          def apply!(messages)
            return unless @collapser.collapsed?

            marked = @manager.marked

            messages.delete_if { |message| marked.include?(message.offset) }
          end
        end
      end
    end
  end
end
