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

          # Nothing to prepare before consumption for the default share flow
          def handle_before_consume
            nil
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
          ensure
            coordinator.decrement(:consume)
          end

          # Settles every record of the batch that the consumer did not acknowledge itself, so that
          # none is left outstanding (librdkafka would refuse the next poll otherwise). After a
          # successful consumption they get the topic `acknowledgements(unacknowledged:)` state
          # (release by default); after a failure they are always released for redelivery.
          #
          # @note The listener flushes the acknowledgements once the whole batch is processed.
          def handle_after_consume
            if coordinator.consumption(self).success?
              client.settle(messages.raw, topic.acknowledgements.unacknowledged)
            else
              client.settle(messages.raw, :release)
            end
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
