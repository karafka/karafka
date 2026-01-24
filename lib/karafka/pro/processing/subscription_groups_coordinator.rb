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
    module Processing
      # Uses the jobs queue API to lock (pause) and unlock (resume) operations of a given
      # subscription group. It is abstracted away from jobs queue on this layer because we do
      # not want to introduce jobs queue as a concept to the consumers layer
      class SubscriptionGroupsCoordinator
        include Singleton

        # @param subscription_group [Karafka::Routing::SubscriptionGroup] subscription group we
        #   want to pause
        # @param lock_id [Object] key we want to use if we want to set multiple locks on the same
        #   subscription group
        def pause(subscription_group, lock_id = nil, **)
          jobs_queue.lock_async(
            subscription_group.id,
            lock_id,
            **
          )
        end

        # @param subscription_group [Karafka::Routing::SubscriptionGroup] subscription group we
        #   want to resume
        # @param lock_id [Object] lock id (if it was used to pause)
        def resume(subscription_group, lock_id = nil)
          jobs_queue.unlock_async(subscription_group.id, lock_id)
        end

        private

        # @return [Karafka::Pro::Processing::JobsQueue]
        def jobs_queue
          @jobs_queue ||= Karafka::Server.jobs_queue
        end
      end
    end
  end
end
