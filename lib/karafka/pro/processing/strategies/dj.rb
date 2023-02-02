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
        # Delayed Jobs enabled and nothing else
        module Dj
          include Default

          # Active features of this strategy
          FEATURES = %i[
            delayed_job
          ].freeze

          # Run the default strategy stuff and then filter out messages that would be too young
          # to be procesed
          def handle_before_consume
            super

            delayer = coordinator.delayer
            delayer.configure(
              topic.delayed_job.delay_for,
              topic.max_wait_time
            )

            # Limit messages to those that are old enough to be processed
            # @note We may end up with not having messages at all for consumption after that
            messages.delete_if do |message|
              delayer.filter?(message)
            end
          end

          # Run the user consumption code
          def handle_consume
            # We should not run the work at all on a partition that was revoked
            # This can happen primarily when an LRJ job gets to the internal worker queue and
            # this partition is revoked prior processing.
            unless revoked? || messages.empty?
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
            coordinator.decrement
          end

          # Standard flow without any features
          def handle_after_consume
            coordinator.on_finished do
              return if revoked?

              if coordinator.success?
                coordinator.pause_tracker.reset

                # Do not mark last message if pause happened. This prevents a scenario where pause
                # is overridden upon rebalance by marking
                return if coordinator.manual_pause?

                # If we limited the scope of what we are processing, we need to only mark
                # as processed in place where we actually finished and not for the whole batch
                # from which too young messages might have been removed
                last_processed = coordinator.delayer.last_processed
                mark_as_consumed(last_processed) if last_processed

                return unless coordinator.delayer.limited?

                continue_after_delay
              else
                retry_after_pause
              end
            end
          end

          private

          # Delay for the expected time and pick up after the last processed message
          def continue_after_delay
            # Start from the last one we agreed on
            seek_offset = coordinator.delayer.seek_offset
            delay = coordinator.delayer.backoff

            pause(seek_offset, delay, false)

            # Instrumentation needs to run **after** `#pause` invocation because we rely on the
            # states set by `#pause`
            Karafka.monitor.instrument(
              'consumer.consuming.delay',
              caller: self,
              topic: messages.metadata.topic,
              partition: messages.metadata.partition,
              offset: seek_offset,
              timeout: delay,
              attempt: coordinator.pause_tracker.attempt
            )
          end
        end
      end
    end
  end
end
