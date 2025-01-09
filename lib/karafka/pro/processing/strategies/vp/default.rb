# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
            # @param offset_metadata [String, nil]
            # @note This virtual offset management uses a regular default marking API underneath.
            #   We do not alter the "real" marking API, as VPs are just one of many cases we want
            #   to support and we do not want to impact them with collective offsets management
            def mark_as_consumed(message, offset_metadata = @_current_offset_metadata)
              if @_in_transaction && !collapsed?
                mark_in_transaction(message, offset_metadata, true)
              elsif collapsed?
                super
              else
                manager = coordinator.virtual_offset_manager

                coordinator.synchronize do
                  manager.mark(message, offset_metadata)
                  # If this is last marking on a finished flow, we can use the original
                  # last message and in order to do so, we need to mark all previous messages as
                  # consumed as otherwise the computed offset could be different
                  # We mark until our offset just in case of a DLQ flow or similar, where we do not
                  # want to mark all but until the expected location
                  manager.mark_until(message, offset_metadata) if coordinator.finished?

                  return revoked? unless manager.markable?

                  manager.markable? ? super(*manager.markable) : revoked?
                end
              end
            ensure
              @_current_offset_metadata = nil
            end

            # @param message [Karafka::Messages::Message] blocking marks message as consumed
            # @param offset_metadata [String, nil]
            def mark_as_consumed!(message, offset_metadata = @_current_offset_metadata)
              if @_in_transaction && !collapsed?
                mark_in_transaction(message, offset_metadata, false)
              elsif collapsed?
                super
              else
                manager = coordinator.virtual_offset_manager

                coordinator.synchronize do
                  manager.mark(message, offset_metadata)
                  manager.mark_until(message, offset_metadata) if coordinator.finished?
                  manager.markable? ? super(*manager.markable) : revoked?
                end
              end
            ensure
              @_current_offset_metadata = nil
            end

            # Stores the next offset for processing inside of the transaction when collapsed and
            # accumulates marking as consumed in the local buffer.
            #
            # Due to nature of VPs we cannot provide full EOS support but we can simulate it,
            # making sure that no offset are stored unless transaction is finished. We do it by
            # accumulating the post-transaction marking requests and after it is successfully done
            # we mark each as consumed. This effectively on errors "rollbacks" the state and
            # prevents offset storage.
            #
            # Since the EOS here is "weak", we do not have to worry about the race-conditions and
            # we do not have to have any mutexes.
            #
            # @param message [Messages::Message] message we want to commit inside of a transaction
            # @param offset_metadata [String, nil] offset metadata or nil if none
            # @param async [Boolean] should we mark in async or sync way (applicable only to post
            #   transaction state synchronization usage as within transaction it is always sync)
            def mark_in_transaction(message, offset_metadata, async)
              raise Errors::TransactionRequiredError unless @_in_transaction
              # Prevent from attempts of offset storage when we no longer own the assignment
              raise Errors::AssignmentLostError if revoked?

              return super if collapsed?
              # If this is user post-execution transaction (one initiated by the system) we should
              # delegate to the original implementation that will store the offset via the producer
              return super if @_transaction_internal

              @_transaction_marked << [message, offset_metadata, async]
            end

            # @return [Boolean] is the virtual processing collapsed in the context of given
            #   consumer.
            def collapsed?
              coordinator.collapsed?
            end

            # @param offset [Integer] first offset from which we should not operate in a collapsed
            #   mode.
            # @note Keep in mind, that if a batch contains this but also messages earlier messages
            #   that should be collapsed, all will continue to operate in a collapsed mode until
            #   first full batch with only messages that should not be collapsed.
            def collapse_until!(offset)
              coordinator.collapse_until!(offset)
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

            # Allows for cross-virtual-partition consumers locks
            #
            # This is not needed in the non-VP flows except LRJ because there is always only one
            # consumer per partition at the same time, so no coordination is needed directly for
            # the end users. With LRJ it is needed and provided in the `LRJ::Default` strategy,
            # because lifecycle events on revocation can run in parallel to the LRJ job as it is
            # non-blocking.
            #
            # @param block [Proc] block we want to run in a mutex to prevent race-conditions
            def synchronize(&block)
              coordinator.shared_mutex.synchronize(&block)
            end

            private

            # Prior to adding work to the queue, registers all the messages offsets into the
            # virtual offset group.
            #
            # @note This can be done without the mutex, because it happens from the same thread
            #   for all the work (listener thread)
            def handle_before_schedule_consume
              super

              # We should not register offsets in virtual manager when in collapse as virtual
              # manager is not used then for offsets materialization.
              #
              # If we would do so, it would cause increased storage in cases of endless errors
              # that are being retried in collapse without a DLQ.
              return if collapsed?

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
