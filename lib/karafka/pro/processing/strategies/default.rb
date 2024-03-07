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
        # No features enabled.
        # No manual offset management
        # No long running jobs
        # No virtual partitions
        # Nothing. Just standard, automatic flow
        module Default
          include Base
          include ::Karafka::Processing::Strategies::Default

          # Apply strategy for a non-feature based flow
          FEATURES = %i[].freeze

          # Allows to set offset metadata that will be used with the upcoming marking as consumed
          # as long as a different offset metadata was not used. After it was used either via
          # `#mark_as_consumed` or `#mark_as_consumed!` it will be set back to `nil`. It is done
          # that way to provide the end user with ability to influence metadata on the non-user
          # initiated markings in complex flows.
          #
          # @param offset_metadata [String, nil] metadata we want to store with the upcoming
          #   marking as consumed
          #
          # @note Please be aware, that offset metadata set this way will be passed to any marking
          #   as consumed even if it was not user initiated. For example in the DLQ flow.
          def store_offset_metadata(offset_metadata)
            @_current_offset_metadata = offset_metadata
          end

          # Marks message as consumed in an async way.
          #
          # @param message [Messages::Message] last successfully processed message.
          # @param offset_metadata [String, nil] offset metadata string or nil if nothing
          # @return [Boolean] true if we were able to mark the offset, false otherwise.
          #   False indicates that we were not able and that we have lost the partition.
          #
          # @note We keep track of this offset in case we would mark as consumed and got error when
          #   processing another message. In case like this we do not pause on the message we've
          #   already processed but rather at the next one. This applies to both sync and async
          #   versions of this method.
          def mark_as_consumed(message, offset_metadata = @_current_offset_metadata)
            if @_in_transaction
              mark_in_transaction(message, offset_metadata, true)
            else
              # seek offset can be nil only in case `#seek` was invoked with offset reset request
              # In case like this we ignore marking
              return true if coordinator.seek_offset.nil?
              # Ignore earlier offsets than the one we already committed
              return true if coordinator.seek_offset > message.offset
              return false if revoked?
              return revoked? unless client.mark_as_consumed(message, offset_metadata)

              coordinator.seek_offset = message.offset + 1
            end

            true
          ensure
            @_current_offset_metadata = nil
          end

          # Marks message as consumed in a sync way.
          #
          # @param message [Messages::Message] last successfully processed message.
          # @param offset_metadata [String, nil] offset metadata string or nil if nothing
          # @return [Boolean] true if we were able to mark the offset, false otherwise.
          #   False indicates that we were not able and that we have lost the partition.
          def mark_as_consumed!(message, offset_metadata = @_current_offset_metadata)
            if @_in_transaction
              mark_in_transaction(message, offset_metadata, false)
            else
              # seek offset can be nil only in case `#seek` was invoked with offset reset request
              # In case like this we ignore marking
              return true if coordinator.seek_offset.nil?
              # Ignore earlier offsets than the one we already committed
              return true if coordinator.seek_offset > message.offset
              return false if revoked?

              return revoked? unless client.mark_as_consumed!(message, offset_metadata)

              coordinator.seek_offset = message.offset + 1
            end

            true
          ensure
            @_current_offset_metadata = nil
          end

          # Starts producer transaction, saves the transaction context for transactional marking
          # and runs user code in this context
          #
          # Transactions on a consumer level differ from those initiated by the producer as they
          # allow to mark offsets inside of the transaction. If the transaction is initialized
          # only from the consumer, the offset will be stored in a regular fashion.
          #
          # @param active_producer [WaterDrop::Producer] alternative producer instance we may want
          #   to use. It is useful when we have connection pool or any other selective engine for
          #   managing multiple producers. If not provided, default producer taken from `#producer`
          #   will be used.
          #
          # @param block [Proc] code that we want to run in a transaction
          #
          # @note Please note, that if you provide the producer, it will reassign the producer of
          #   the consumer for the transaction time. This means, that in case you would even
          #   accidentally refer to `Consumer#producer` from other threads, it will contain the
          #   reassigned producer and not the initially used/assigned producer. It is done that
          #   way, so the message producing aliases operate from within transactions and since the
          #   producer in transaction is locked, it will prevent other threads from using it.
          def transaction(active_producer = producer, &block)
            default_producer = producer
            self.producer = active_producer

            transaction_started = false

            # Prevent from nested transactions. It would not make any sense
            raise Errors::TransactionAlreadyInitializedError if @_in_transaction

            transaction_started = true
            @_transaction_marked = []
            @_in_transaction = true

            producer.transaction(&block)

            @_in_transaction = false

            # This offset is already stored in transaction but we set it here anyhow because we
            # want to make sure our internal in-memory state is aligned with the transaction
            #
            # @note We never need to use the blocking `#mark_as_consumed!` here because the offset
            #   anyhow was already stored during the transaction
            #
            # @note In theory we could only keep reference to the most recent marking and reject
            #   others. We however do not do it for two reasons:
            #   - User may have non standard flow relying on some alternative order and we want to
            #     mimic this
            #   - Complex strategies like VPs can use this in VPs to mark in parallel without
            #     having to redefine the transactional flow completely
            @_transaction_marked.each do |marking|
              marking.pop ? mark_as_consumed(*marking) : mark_as_consumed!(*marking)
            end
          ensure
            self.producer = default_producer

            if transaction_started
              @_transaction_marked.clear
              @_in_transaction = false
            end
          end

          # Stores the next offset for processing inside of the transaction and stores it in a
          # local accumulator for post-transaction status update
          #
          # @param message [Messages::Message] message we want to commit inside of a transaction
          # @param offset_metadata [String, nil] offset metadata or nil if none
          # @param async [Boolean] should we mark in async or sync way (applicable only to post
          #   transaction state synchronization usage as within transaction it is always sync)
          def mark_in_transaction(message, offset_metadata, async)
            raise Errors::TransactionRequiredError unless @_in_transaction
            raise Errors::AssignmentLostError if revoked?

            producer.transaction_mark_as_consumed(
              client,
              message,
              offset_metadata
            )

            @_transaction_marked ||= []
            @_transaction_marked << [message, offset_metadata, async]
          end

          # No actions needed for the standard flow here
          def handle_before_schedule_consume
            Karafka.monitor.instrument('consumer.before_schedule_consume', caller: self)

            nil
          end

          # Increment number of attempts per one "full" job. For all VP on a single topic partition
          # this also should run once.
          def handle_before_consume
            coordinator.on_started do
              coordinator.pause_tracker.increment
            end
          end

          # Run the user consumption code
          def handle_consume
            # We should not run the work at all on a partition that was revoked
            # This can happen primarily when an LRJ job gets to the internal worker queue and
            # this partition is revoked prior processing.
            unless revoked?
              Karafka.monitor.instrument('consumer.consume', caller: self)
              Karafka.monitor.instrument('consumer.consumed', caller: self) do
                consume
              end
            end

            # Mark job as successful
            coordinator.success!(self)
          rescue StandardError => e
            # If failed, mark as failed
            coordinator.failure!(self, e)

            # Re-raise so reported in the consumer
            raise e
          ensure
            # We need to decrease number of jobs that this coordinator coordinates as it has
            # finished
            coordinator.decrement(:consume)
          end

          # Standard flow without any features
          def handle_after_consume
            coordinator.on_finished do |last_group_message|
              return if revoked?

              if coordinator.success?
                coordinator.pause_tracker.reset

                # Do not mark last message if pause happened. This prevents a scenario where pause
                # is overridden upon rebalance by marking
                return if coordinator.manual_pause?

                mark_as_consumed(last_group_message)
              else
                retry_after_pause
              end
            end
          end

          # Standard flow for revocation
          def handle_revoked
            coordinator.on_revoked do
              resume

              coordinator.revoke
            end

            Karafka.monitor.instrument('consumer.revoke', caller: self)
            Karafka.monitor.instrument('consumer.revoked', caller: self) do
              revoked
            end
          ensure
            coordinator.decrement(:revoked)
          end

          # No action needed for the tick standard flow
          def handle_before_schedule_tick
            Karafka.monitor.instrument('consumer.before_schedule_tick', caller: self)

            nil
          end

          # Runs the consumer `#tick` method with reporting
          def handle_tick
            Karafka.monitor.instrument('consumer.tick', caller: self)
            Karafka.monitor.instrument('consumer.ticked', caller: self) do
              tick
            end
          ensure
            coordinator.decrement(:periodic)
          end
        end
      end
    end
  end
end
