# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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
