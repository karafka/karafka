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
    module Connection
      # Manager that can handle working with multiplexed connections.
      #
      # This manager takes into consideration the number of partitions assigned to the topics and
      # does it best to balance. Additional connections may not always be utilized because
      # alongside of them, other processes may "highjack" the assignment. In such cases those extra
      # empty connections will be turned off after a while.
      #
      # @note Manager operations relate to consumer groups and not subscription groups. Since
      #   cluster operations can cause consumer group wide effects, we always apply only one
      #   change on a consumer group
      class Manager < Karafka::Connection::Manager
        include Core::Helpers::Time

        # How long should we wait after a rebalance before doing anything on a consumer group
        # @param change_delay [Integer] what should be the delay before applying any changes after
        #   last change on a consumer group. This allows us for stabilization so we do not cause
        #   many rebalances too often. By default it is one minute.
        def initialize(change_delay: 60 * 1_000)
          super()
          @change_delay = change_delay
          @changes = Hash.new { |h, k| h[k] = monotonic_now }
        end

        # Marks most recent time on a given consumer group. This is used to back-off any
        # operations on this CG until it is in a stable state for long enough.
        # @param consumer_group_id [String] consumer group id
        def notice(consumer_group_id)
          @changes[consumer_group_id] = monotonic_now
        end
      end
    end
  end
end
