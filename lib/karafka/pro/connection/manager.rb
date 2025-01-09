# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

module Karafka
  module Pro
    module Connection
      # Manager that can handle working with multiplexed connections.
      #
      # This manager takes into consideration the number of partitions assigned to the topics and
      # does its best to balance. Additional connections may not always be utilized because
      # alongside of them, other processes may "hijack" the assignment. In such cases those extra
      # empty connections will be turned off after a while.
      #
      # @note Manager operations relate to consumer groups and not subscription groups. Since
      #   cluster operations can cause consumer group wide effects, we always apply only one
      #   change on a consumer group.
      class Manager < Karafka::Connection::Manager
        include Core::Helpers::Time

        # How long should we wait after a rebalance before doing anything on a consumer group
        #
        # @param scale_delay [Integer] How long should we wait before making any changes. Any
        #   change related to this consumer group will postpone the scaling operations. This is
        #   done that way to prevent too many friction in the cluster. It is 1 minute by default
        def initialize(scale_delay = 60 * 1_000)
          super()
          @scale_delay = scale_delay
          @mutex = Mutex.new
          @changes = Hash.new do |h, k|
            h[k] = {
              state: '',
              join_state: '',
              state_age: 0,
              changed_at: monotonic_now
            }
          end
        end

        # Registers listeners and starts the scaling procedures
        #
        # When using dynamic multiplexing, it will start the absolute minimum of connections for
        # subscription group available.
        #
        # @param listeners [Connection::ListenersBatch]
        def register(listeners)
          @listeners = listeners

          # Preload all the keys into the hash so we never add keys to changes but just change them
          listeners.each { |listener| @changes[listener.subscription_group.id] }

          in_sg_families do |first_subscription_group, sg_listeners|
            multiplexing = first_subscription_group.multiplexing

            if multiplexing.active? && multiplexing.dynamic?
              # Start as many boot listeners as user wants. If not configured, starts half of max.
              sg_listeners.first(multiplexing.boot).each(&:start!)
            else
              sg_listeners.each(&:start!)
            end
          end
        end

        # Collects data from the statistics about given subscription group. This is used to ensure
        # that we do not rescale short after rebalances, deployments, etc.
        # @param subscription_group_id [String] id of the subscription group for which statistics
        #   were emitted
        # @param statistics [Hash] emitted statistics
        #
        # @note Please note that while we collect here per subscription group, we use those metrics
        #   collectively on a whole consumer group. This reduces the friction.
        def notice(subscription_group_id, statistics)
          times = []
          # stateage is in microseconds
          # We monitor broker changes to make sure we do not introduce extra friction
          times << statistics['brokers'].values.map { |stats| stats['stateage'] }.min / 1_000
          times << statistics['cgrp']['rebalance_age']
          times << statistics['cgrp']['stateage']

          # Keep the previous change age for changes that were triggered by us
          previous_changed_at = @changes[subscription_group_id][:changed_at]

          @changes[subscription_group_id].merge!(
            state_age: times.min,
            changed_at: previous_changed_at,
            join_state: statistics['cgrp']['join_state'],
            state: statistics['cgrp']['state']
          )
        end

        # Shuts down all the listeners when it is time (including moving to quiet) or rescales
        # when it is needed
        def control
          Karafka::App.done? ? shutdown : rescale
        end

        private

        # Handles the shutdown and quiet flows
        def shutdown
          active_listeners = @listeners.active

          # When we are done processing immediately quiet all the listeners so they do not pick up
          # new work to do
          once(:quiet!) { active_listeners.each(&:quiet!) }

          # If we are in the process of moving to quiet state, we need to check it.
          if Karafka::App.quieting?
            # If we are quieting but not all active listeners are quiet we need to wait for all of
            # them to reach the quiet state
            return unless active_listeners.all?(&:quiet?)

            once(:quieted!) { Karafka::App.quieted! }
          end

          # Do nothing if we moved to quiet state and want to be in it
          return if Karafka::App.quiet?

          # Since separate subscription groups are subscribed to different topics, there is no risk
          # in shutting them down independently even if they operate in the same subscription group
          in_sg_families do |first_subscription_group, sg_listeners|
            active_sg_listeners = sg_listeners.select(&:active?)

            # Do nothing until all listeners from the same consumer group are quiet. Otherwise we
            # could have problems with in-flight rebalances during shutdown
            next unless active_sg_listeners.all?(&:quiet?)

            # Do not stop the same family twice
            once(:stop!, first_subscription_group.name) { active_sg_listeners.each(&:stop!) }
          end

          return unless @listeners.active.all?(&:stopped?)

          # All listeners including pending need to be moved at the end to stopped state for
          # the whole server to stop
          once(:stop!) { @listeners.each(&:stopped!) }
        end

        # Handles two scenarios:
        #   - Selects subscriptions that could benefit from having more parallel connections
        #     to kafka and then upscales them
        #   - Selects subscriptions that are idle (have nothing subscribed to them) and then shuts
        #     them down
        #
        # We always run scaling down and up because it may be applicable to different CGs
        def rescale
          scale_down
          scale_up
        end

        # Checks for connections without any assignments and scales them down.
        # Does that only for dynamically multiplexed subscription groups
        def scale_down
          sgs_in_use = Karafka::App.assignments.keys.map(&:subscription_group).uniq

          # Select connections for scaling down
          in_sg_families do |first_subscription_group, sg_listeners|
            next unless stable?(sg_listeners)

            multiplexing = first_subscription_group.multiplexing

            next unless multiplexing.active?
            next unless multiplexing.dynamic?

            # If we cannot downscale, do not
            next if sg_listeners.count(&:active?) <= multiplexing.min

            sg_listeners.each do |sg_listener|
              # Do not stop connections with subscriptions
              next if sgs_in_use.include?(sg_listener.subscription_group)
              # Skip listeners that are already in standby
              next unless sg_listener.active?

              touch(sg_listener.subscription_group.id)

              # Shut down not used connection
              sg_listener.stop!

              break
            end
          end
        end

        # Checks if we have space to scale and if there are any assignments with multiple topics
        # partitions assigned in sgs that can be scaled. If that is the case, we scale up.
        def scale_up
          multi_part_sgs_families = Karafka::App
                                    .assignments
                                    .select { |_, partitions| partitions.size > 1 }
                                    .keys
                                    .map(&:subscription_group)
                                    .map(&:name)
                                    .uniq

          # Select connections for scaling up
          in_sg_families do |first_subscription_group, sg_listeners|
            next unless stable?(sg_listeners)

            multiplexing = first_subscription_group.multiplexing

            next unless multiplexing.active?
            next unless multiplexing.dynamic?
            # If we cannot downscale, do not
            next if sg_listeners.count(&:active?) >= multiplexing.max

            sg_listeners.each do |sg_listener|
              next unless multi_part_sgs_families.include?(sg_listener.subscription_group.name)
              # Skip already active connections
              next unless sg_listener.pending? || sg_listener.stopped?
              # Ensure that the listener thread under which we operate is already stopped and
              # is not dangling. While not likely to happen, this may protect against a
              # case where a shutdown critical crash would case a restart of the same listener
              next if sg_listener.alive?

              touch(sg_listener.subscription_group.id)
              sg_listener.start!

              break
            end
          end
        end

        # Indicates, that something has changed on a subscription group. We consider every single
        # change we make as a change to the setup as well.
        # @param subscription_group_id [String]
        def touch(subscription_group_id)
          @changes[subscription_group_id][:changed_at] = 0
        end

        # @param sg_listeners [Array<Listener>] listeners from one multiplexed sg
        # @return [Boolean] is given subscription group listeners set stable. It is considered
        #   stable when it had no changes happening on it recently and all relevant states in it
        #   are also stable. This is a strong indicator that no rebalances or other operations are
        #   happening at a given moment.
        def stable?(sg_listeners)
          sg_listeners.all? do |sg_listener|
            # If a listener is not active, we do not take it into consideration when looking at
            # the stability data
            next true unless sg_listener.active?

            state = @changes[sg_listener.subscription_group.id]

            state[:state_age] >= @scale_delay &&
              (monotonic_now - state[:changed_at]) >= @scale_delay &&
              state[:state] == 'up' &&
              state[:join_state] == 'steady'
          end
        end

        # Yields listeners in groups based on their subscription groups
        # @yieldparam [Karafka::Routing::SubscriptionGroup] first subscription group out of the
        #   family
        # @yieldparam [Array<Listener>] listeners of a single subscription group
        def in_sg_families
          grouped = @listeners.group_by { |listener| listener.subscription_group.name }

          grouped.each_value do |listeners|
            listener = listeners.first

            yield(
              listener.subscription_group,
              listeners
            )
          end
        end
      end
    end
  end
end
