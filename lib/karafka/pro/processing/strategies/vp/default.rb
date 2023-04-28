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
      module Strategies
        # VP starting strategies
        module Vp
          # Just Virtual Partitions enabled
          module Default
            # This flow is exactly the same as the default one because the default one is wrapper
            # with `coordinator#on_finished`
            include Strategies::Default

            # Features for this strategy
            FEATURES = %i[
              virtual_partitions
            ].freeze

            # @param message [Karafka::Messages::Message] marks message as consumed
            # @note This virtual offset management uses a regular default marking API underneath.
            #   We do not alter the "real" marking API, as VPs are just one of many cases we want
            #   to support and we do not want to impact them with collective offsets management
            def mark_as_consumed(message)
              return super if collapsed?

              manager = coordinator.virtual_offset_manager

              coordinator.synchronize do
                manager.mark(message)
                # If this is last marking on a finished flow, we can use the original
                # last message and in order to do so, we need to mark all previous messages as
                # consumed as otherwise the computed offset could be different
                # We mark until our offset just in case of a DLQ flow or similar, where we do not
                # want to mark all but until the expected location
                manager.mark_until(message) if coordinator.finished?

                return revoked? unless manager.markable?
              end

              manager.markable? ? super(manager.markable) : revoked?
            end

            # @param message [Karafka::Messages::Message] blocking marks message as consumed
            def mark_as_consumed!(message)
              return super if collapsed?

              manager = coordinator.virtual_offset_manager

              coordinator.synchronize do
                manager.mark(message)
                manager.mark_until(message) if coordinator.finished?
              end

              manager.markable? ? super(manager.markable) : revoked?
            end

            # @return [Boolean] is the virtual processing collapsed in the context of given
            #   consumer.
            def collapsed?
              coordinator.collapsed?
            end

            # @return [Boolean] true if any of virtual partition we're operating in the entangled
            #   mode has already failed and we know we are failing collectively.
            #   Useful for early stop to minimize number of things processed twice.
            #
            # @note We've named it `#failing?` instead of `#failure?`  because it aims to be used
            #   from within virtual partitions where we want to have notion of collective failing
            #   not just "local" to our processing. We "are" failing with other virtual partitions
            #   raising an error, but locally we are still processing.
            def failing?
              coordinator.failure?
            end

            private

            # Prior to adding work to the queue, registers all the messages offsets into the
            # virtual offset group.
            #
            # @note This can be done without the mutex, because it happens from the same thread
            #   for all the work (listener thread)
            def handle_before_enqueue
              coordinator.virtual_offset_manager.register(
                messages.map(&:offset)
              )
            end
          end
        end
      end
    end
  end
end
