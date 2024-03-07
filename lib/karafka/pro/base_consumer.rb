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
    # Extra methods always used in the base consumer in the pro mode
    #
    # We do not define those methods as part of the strategies flows, because they are injected
    # (strategies) on singletons and often used only in one of the strategy variants
    #
    # Methods here are suppose to be always available or are expected to be redefined
    module BaseConsumer
      # Runs the on-schedule tick periodic operations
      # This method is an alias but is part of the naming convention used for other flows, this
      # is why we do not reference the `handle_before_schedule_tick` directly
      def on_before_schedule_tick
        handle_before_schedule_tick
      end

      # Used by the executor to trigger consumer tick
      # @private
      def on_tick
        handle_tick
      rescue StandardError => e
        Karafka.monitor.instrument(
          'error.occurred',
          error: e,
          caller: self,
          type: 'consumer.tick.error'
        )
      end

      # By default we do nothing when ticking
      def tick; end

      # @return [Karafka::Pro::Processing::Coordinators::ErrorsTracker] tracker for errors that
      #   occurred during processing until another successful processing
      #
      # @note This will always contain **only** details of errors that occurred during `#consume`
      #   because only those are retryable.
      #
      # @note This may contain more than one error because:
      #   - this can collect various errors that might have happened during virtual partitions
      #     execution
      #   - errors can pile up during retries and until a clean run, they will be collected with
      #     a limit of last 100. We do not store more because a consumer with an endless error loop
      #     would cause memory leaks without such a limit.
      def errors_tracker
        coordinator.errors_tracker
      end

      # @return [Karafka::Pro::Processing::SubscriptionGroupsCoordinator] Coordinator allowing to
      #   pause and resume polling of the given subscription group jobs queue for postponing
      #   further work.
      #
      # @note Since this stops polling, it can cause reaching `max.poll.interval.ms` limitations.
      #
      # @note This is a low-level API used for cross-topic coordination and some advanced features.
      #   Use it at own risk.
      def subscription_groups_coordinator
        Processing::SubscriptionGroupsCoordinator.instance
      end
    end
  end
end
