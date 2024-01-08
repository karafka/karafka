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
      # @note Manager operations relate to consumer groups and not subscription groups. Since
      #   cluster operations can cause consumer group wide effects, we always apply only one
      #   change on a consumer group
      class Manager < Karafka::Connection::Manager
        include Core::Helpers::Time

        # How long should we wait after a rebalance before doing anything on a consumer group
        def initialize(change_delay: 1 * 1_000)
          super()
          @change_delay = change_delay
          @changes = Hash.new { |h, k| h[k] = monotonic_now }
        end

        # Registers listeners and starts the scaling procedures
        #
        # @param listeners [Connection::ListenersBatch]
        def register(listeners)
          @listeners = listeners

          in_families do |subscription_group, multiplexing, sg_listeners|
            notice(subscription_group.consumer_group)

            if multiplexing.active? && multiplexing.dynamic?
              # Start absolute minimum that is expected in this multiplexed group for now and leave
              # the upscaling for later. This will minimize number of connections in total in
              # all consumer groups effectively allowing for faster start
              sg_listeners[0...multiplexing.min].each(&:start)
            else
              sg_listeners.each(&:start)
            end
          end
        end

        def in_families
          grouped = @listeners.group_by { |listener| listener.subscription_group.name }

          grouped.each_value do |listeners|
            listener = listeners.first

            yield(
              listener.subscription_group,
              listener.subscription_group.multiplexing,
              listeners
            )
          end
        end

        # Marks most recent time on a given consumer group. This is used to back-off any
        # operations on this CG until it is in a stable state for long enough.
        # @param consumer_group_id [String] consumer group id
        def notice(consumer_group_id)
          @changes[consumer_group_id] = monotonic_now
        end

        def scale
          # Do nothing if we just started to stop the process
          return if Karafka::App.done?
        end
      end
    end
  end
end
