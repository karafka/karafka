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
      # Uses the jobs queue API to lock (pause) and unlock (resume) operations of a given
      # subscription group. It is abstracted away from jobs queue on this layer because we do
      # not want to introduce jobs queue as a concept to the consumers layer
      class SubscriptionGroupsCoordinator
        include Singleton

        # @param subscription_group [Karafka::Routing::SubscriptionGroup] subscription group we
        #   want to pause
        # @param lock_id [Object] key we want to use if we want to set multiple locks on the same
        #   subscription group
        # @param kwargs [Object] Any keyword arguments accepted by the jobs queue lock.
        def pause(subscription_group, lock_id = nil, **kwargs)
          jobs_queue.lock_async(
            subscription_group.id,
            lock_id,
            **kwargs
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
