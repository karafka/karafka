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
      # alongside of them, other processes may "hijack" the assignment. In such cases those extra
      # empty connections will be turned off after a while.
      #
      # @note Manager operations relate to consumer groups and not subscription groups. Since
      #   cluster operations can cause consumer group wide effects, we always apply only one
      #   change on a consumer group
      class Manager < Karafka::Connection::Manager
        include Core::Helpers::Time

        # How long should we wait after a rebalance before doing anything on a consumer group
        #
        # @param initial_delay [Integer] how long should we wait after start of the process, before
        #   we take any scaling action. During deployments it may take the whole cluster a moment
        #   to reach a stable state, hence we delay that independetly from making intermediate
        #   decisions
        # @param scale_down_delay [Integer] lag between last known change on a given consumer group
        #   and the moment we can scale down. Since we scale down only empty connections, this
        #   can be shorter than the scale up delay.
        # @param scale_up_delay [Integer] Delay in-between last change on a consumer group and
        #   the moment we can scale up the listeners. Since scaling up may cause revocation of
        #   some partitions, we want to do it slowly not to cause issues in the cluster. Depending
        #   on the type of work and its time it may be desirable to have it longer or shorter.
        def initialize(
          initial_delay: 5 * 60 * 10_0,
          scale_down_delay: 60 * 10_0,
          scale_up_delay: 5 * 60 * 10_0
        )
          super()
          @initial_delay = initial_delay
          @scale_down_delay = scale_down_delay
          @scale_up_delay = scale_up_delay
          @started_at = monotonic_now
          @mutex = Mutex.new
          @changes = Hash.new do |h, k|
            h[k] = {
              state: '',
              join_state: '',
              state_age: 0,
              state_age_sync: monotonic_now
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

          in_sg_families do |subscription_group, sg_listeners|
            consumer_group = sg_listeners.first.subscription_group.consumer_group
            subscription_group = sg_listeners.first.subscription_group

            multiplexing = subscription_group.multiplexing

            if multiplexing.active? && multiplexing.dynamic?
              # Start absolute minimum that is expected in this multiplexed group for now and leave
              # the upscaling for later. This will minimize number of connections in total in
              # all consumer groups effectively allowing for faster start
              #
              # Once we reach a stable state, we can then upscale/downcase slowly as needed
              sg_listeners.each(&:start!)
            else
              sg_listeners.each(&:start!)
            end
          end
        end

        def notice(subscription_group_id, statistics)
          @mutex.synchronize do
            times = []

            times << statistics['brokers'].values.map { |stats| stats['stateage'] }.min / 1000
            times << statistics['cgrp']['rebalance_age']
            times << statistics['cgrp']['stateage']

            @changes[subscription_group_id][:state_age] = times.min
            @changes[subscription_group_id][:join_state] = statistics['cgrp']['join_state']
            @changes[subscription_group_id][:state] = statistics['cgrp']['state']
            @changes[subscription_group_id][:state_age_sync] = monotonic_now
          end
        end

        def touch(subscription_group_id)
          @mutex.synchronize do
            @changes[subscription_group_id][:state_age] = 0
            @changes[subscription_group_id][:state_age_sync] = monotonic_now

            @changes.delete_if do |k, v|
              monotonic_now - v[:state_age_sync] >= 30_000
            end
          end
        end

        # Shuts down all the listeners when it is time (including moving to quiet) or rescales
        # when it is needed
        def control
          @mutex.synchronize do
            @changes.delete_if do |k, v|
              monotonic_now - v[:state_age_sync] >= 30_000
            end
          end

          p 'xxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxxx'

          Karafka::App.done? ? shutdown : rescale
        end

        private

        # Handles two scenarios:
        #   - Selects subscriptions that could benefit from having more parallel connections
        #     to kafka and then upscales them
        #   - Selects subscriptions that are idle (have nothing subscribed to them) and then shuts
        #     them down
        def rescale
          #return
          p 'aaaa'
          # Do not take any actions if process is not alive for enough time
          p [monotonic_now - @started_at, @initial_delay]
          #return if monotonic_now - @started_at < @initial_delay

          p 'uuuuuuuuuuuuu'

          scale_down

          scale_up
        end

        # Handles the shutdown and quiet flows
        def shutdown
          active_listeners = @listeners.active

          # When we are done processing immediately quiet all the listeners so they do not pick up
          # new work to do
          unless @silencing
            active_listeners.each(&:quiet!)
            @silencing = true

            return
          end

          # If we are in the process of moving to quiet state, we need to check it.
          if Karafka::App.quieting?
            # Switch to quieted status only when all listeners are fully quieted and do nothing
            # after that until further state changes
            return unless active_listeners.all?(&:quiet?)

            Karafka::App.quieted!
          end

          p Rdkafka::Config.opaques

          p 'h1'

          return if Karafka::App.quiet?

          p 'h2'
          @stopped_subscription_groups ||= Set.new

          p 'h3'
          # Since separate subscription groups are subscribed to different topics, there is no risk
          # in shutting them down independently even if they operate in the same subscription group
          in_sg_families do |subscription_group, sg_listeners|
            active_sg_listeners = sg_listeners.select(&:active?)

            # Do nothing until all listeners from the same consumer group are quiet. Otherwise we
            # could have problems with in-flight rebalances during shutdown
            next unless active_sg_listeners.all?(&:quiet?)
            # Do not stop the same sg twice
            next if @stopped_subscription_groups.include?(subscription_group)

            @stopped_subscription_groups << subscription_group

            active_sg_listeners.each(&:stop!)
          end

          p 'h4'
          p @listeners.map(&:status)

          return unless @listeners.active.all?(&:stopped?)

          # All listeners including pending need to be moved at the end to stopped state for
          # the whole server to stop
          @listeners.each(&:stop!)
        end

        def scale_down
          p 'scaling down check...'
          sgs_in_use = Karafka::App.assignments.keys.map(&:subscription_group).uniq

          # Select connections for scaling down
          in_sg_families do |subscription_group_name, sg_listeners|
            p stable?(sg_listeners)
            next unless stable?(sg_listeners)

            subscription_group = sg_listeners.first.subscription_group
            consumer_group =  sg_listeners.first.subscription_group.consumer_group
            multiplexing = subscription_group.multiplexing

            next unless multiplexing.active?
            next unless multiplexing.dynamic?
            # If we cannot downscale, do not
            next if sg_listeners.count(&:active?) <= multiplexing.min

            sg_listeners.each do |sg_listener|
              # Do not stop connections with subscriptions
              next if sgs_in_use.include?(sg_listener.subscription_group)
              # Skip listeners that are already in standby
              next unless sg_listener.active?

              # Shut down not used connection
              sg_listener.stop!

              break
            end
          end
        end

        def stable?(sg_listeners)
          p 'test'

          sg_listeners.all? do |sg_listener|
            next true unless @changes.key?(sg_listener.subscription_group.id)

            state = @changes.fetch(sg_listener.subscription_group.id)

            p state

            state[:state_age] >= @scale_up_delay &&
              state[:state] == 'up' &&
              state[:join_state] == 'steady'
          end
        end

        def scale_up
          multi_part_sgs_families = Karafka::App
                             .assignments
                             .select { |_, partitions| partitions.size > 1 }
                             .keys
                             .map(&:subscription_group)
                             .map(&:name)
                             .uniq

          # Select connections for scaling up
          in_sg_families do |subscription_group_name, sg_listeners|
            next unless stable?(sg_listeners)

            subscription_group = sg_listeners.first.subscription_group
            consumer_group = sg_listeners.first.subscription_group.consumer_group
            multiplexing = subscription_group.multiplexing

            next unless multiplexing.active?
            next unless multiplexing.dynamic?
            # If we cannot downscale, do not
            next if sg_listeners.count(&:active?) >= multiplexing.max

            sg_listeners.each do |sg_listener|
              next unless multi_part_sgs_families.include?(sg_listener.subscription_group.name)
              # Skip already active connections
              next unless sg_listener.pending? || sg_listener.stopped?


              p 'startinggggggggggggggggggggggggggggggg'
              touch(sg_listener.subscription_group.id)
              sg_listener.start!

              break
            end
          end
        end

        def too_early?(consumer_group, delay)
          (monotonic_now - @changes[consumer_group.id]) < delay
        end

        # Yields listeners in groups based on their subscription groups
        # @yieldparam [Karafka::Routing::SubscriptionGroup] subscription group of given listeners
        # @yieldparam [Array<Listener>] listeners of a single subscription group
        def in_sg_families
          grouped = @listeners.group_by { |listener| listener.subscription_group.name }

          grouped.each_value do |listeners|
            listener = listeners.first

            yield(
              listener.subscription_group.name,
              listeners
            )
          end
        end
      end
    end
  end
end
