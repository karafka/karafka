# frozen_string_literal: true

module Karafka
  module Processing
    module ShareGroups
      # Processing strategies for share-group consumers.
      module Strategies
        # Default share-group processing flow:
        # - runs the user `#consume` (during which the user acknowledges records via
        #   `#mark_as_accepted` / `#mark_as_released` / `#mark_as_rejected`)
        # - on success, settles records left unacknowledged with the topic
        #   `acknowledgements(unacknowledged:)` state (release by default)
        # - on failure, releases records left unacknowledged for redelivery (at-least-once)
        module Default
          # No features enabled for this flow
          FEATURES = %i[].freeze

          # By default on all "before schedule" hooks we just run instrumentation
          %i[
            consume
            idle
            shutdown
          ].each do |action|
            class_eval <<~RUBY, __FILE__, __LINE__ + 1
              def handle_before_schedule_#{action}
                monitor.instrument('consumer.before_schedule_#{action}', caller: self)

                nil
              end
            RUBY
          end

          # Runs the post-creation, post-assignment code
          def handle_initialized
            monitor.instrument("consumer.initialize", caller: self)
            monitor.instrument("consumer.initialized", caller: self) do
              initialized
            end
          end

          # A new batch is about to be consumed, so this consumer starts tracking its
          # acknowledgements anew
          def handle_before_consume
            acknowledgements_tracker.clear
          end

          # Runs the wrapping to execute the appropriate action wrapped with the wrapper code
          #
          # @param action [Symbol]
          # @param block [Proc]
          def handle_wrap(action, &block)
            monitor.instrument("consumer.wrap", caller: self)
            monitor.instrument("consumer.wrapped", caller: self) do
              wrap(action, &block)
            end
          end

          # Runs the user consumption code
          def handle_consume
            monitor.instrument("consumer.consume", caller: self)
            monitor.instrument("consumer.consumed", caller: self) do
              consume
            end

            coordinator.success!(self)
          # Containment is intentionally broader than StandardError so that a non-StandardError
          # does not leave the consumption in its default (successful) state and skip the
          # after-consume acknowledgement flush.
          rescue Exception => e
            coordinator.failure!(self, e)

            raise e
          end

          # Settles every record of the batch that the consumer did not acknowledge itself, so that
          # none is left outstanding (librdkafka would refuse the next poll otherwise). After a
          # successful consumption they get the topic `acknowledgements(unacknowledged:)` state
          # (release by default); after a failure they are always released for redelivery.
          #
          # Once every consumer of the partition (more than one with virtual partitions) settled
          # its records, the last one flushes the acknowledgements to the broker asynchronously, so
          # those of the whole partition go out in one request.
          def handle_after_consume
            state = if coordinator.consumption(self).success?
              topic.acknowledgements.unacknowledged
            else
              :release
            end

            # Records already acknowledged by the consumer are skipped (each record can be
            # acknowledged only once)
            messages.raw.each { |message| acknowledge(message, state) }
          ensure
            client.commit if coordinator.decrement(:consume).zero?
          end

          # Idle run handling (no messages passed to the end user). Runs housekeeping when a batch
          # is emptied before it reaches the user (e.g. by a future filtering/throttling feature).
          #
          # @note Only `:consume` is tracked by the coordinator (for the success check); idle and
          #   shutdown jobs are tracked by the jobs queue itself, so there is no counter to
          #   decrement here.
          def handle_idle
            nil
          end

          # Runs the shutdown code
          def handle_shutdown
            monitor.instrument("consumer.shutting_down", caller: self)
            monitor.instrument("consumer.shutdown", caller: self) do
              shutdown
            end
          end
        end
      end
    end
  end
end
