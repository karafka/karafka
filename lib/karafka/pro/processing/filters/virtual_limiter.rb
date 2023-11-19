# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

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
