# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    # Extra methods always used in the base consumer in the pro mode
    #
    # We do not define those methods as part of the strategies flows, because they are injected
    # (strategies) on singletons and often used only in one of the strategy variants
    #
    # Methods here are suppose to be always available or are expected to be redefined
    module BaseConsumer
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
