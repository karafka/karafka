# frozen_string_literal: true

module Karafka
  # Namespace for Kafka connection related logic
  module Connection
    # Connections manager responsible for starting and managing listeners connections
    #
    # In the OSS version it starts listeners as they are without any connection management or
    # resources utilization supervision and shuts them down or quiets  when time has come
    class Manager
      # Registers provided listeners and starts all of them
      #
      # @param listeners [Connection::ListenersBatch]
      def register(listeners)
        @listeners = listeners
        @listeners.each(&:start!)
      end

      # @return [Boolean] true if all listeners are stopped
      def done?
        @listeners.all?(&:stopped?)
      end

      # Controls the state of listeners upon shutdown and quiet requests
      # In both cases (quieting and shutdown) we first need to stop processing more work and tell
      # listeners to become quiet (connected but not yielding messages) and then depending on
      # whether we want to stop fully or just keep quiet we apply different flow.
      #
      # @note It is important to ensure, that all listeners from the same consumer group are always
      #   all quiet before we can fully shutdown given consumer group. Skipping this can cause
      #   `Timed out LeaveGroupRequest in flight` and other errors.
      def control
        # Do nothing until shutdown or quiet
        return unless Karafka::App.done?

        # When we are done processing immediately quiet all the listeners so they do not pick up
        # new work to do
        @listeners.each(&:quiet!) unless @silencing
        @silencing = true

        # Switch to quieted status only when all listeners are fully quieted and do nothing after
        # that until further state changes
        if @listeners.all?(&:quiet?) && Karafka::App.quieting?
          Karafka::App.quieted!

          return
        end

        @stopped_consumer_groups ||= Set.new

        in_cg_families do |consumer_group, cg_listeners|
          # Do nothing until all listeners from the same consumer group are quiet. Otherwise we
          # could have problems with in-flight rebalances during shutdown
          next unless cg_listeners.all?(&:quiet?)
          # Do not stop the same cg twice
          next if @stopped_consumer_groups.include?(consumer_group)

          @stopped_consumer_groups << consumer_group

          cg_listeners.each(&:stop!)
        end
      end

      private

      # Yields listeners in groups based on their consumer groups
      # @param block [Proc] block we want to run
      # @yieldparam [Karafka::Routing::ConsumerGroup] consumer group of given listeners
      # @yieldparam [Array<Listener>] listeners of a single consumer group
      def in_cg_families(&block)
        @listeners
          .group_by { |listener| listener.subscription_group.consumer_group }
          .each(&block)
      end
    end
  end
end
