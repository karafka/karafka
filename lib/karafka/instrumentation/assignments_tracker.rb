# frozen_string_literal: true

module Karafka
  module Instrumentation
    # Keeps track of active assignments and materializes them by returning the routing topics
    # with appropriate partitions that are assigned at a given moment
    #
    # It is auto-subscribed as part of Karafka itself.
    #
    # It is not heavy from the computational point of view, as it only operates during rebalances.
    #
    # We keep assignments as flat topics structure because we can go from topics to both
    # subscription and consumer groups if needed.
    class AssignmentsTracker
      include Singleton

      class << self
        # @return [Hash{Karafka::Routing::Topic => Array<Integer>}]
        # @see #current
        def current
          instance.current
        end

        # @return [Hash{Karafka::Routing::Topic => Hash{Integer => Integer}}]
        # @see #generations
        def generations
          instance.generations
        end

        # @param topic [Karafka::Routing::Topic]
        # @param partition [Integer]
        # @return [Integer]
        # @see #generation
        def generation(topic, partition)
          instance.generation(topic, partition)
        end
      end

      # Initializes the assignments tracker with empty assignments
      def initialize
        @mutex = Mutex.new
        @assignments = Hash.new { |hash, key| hash[key] = [] }
        @generations = Hash.new { |h, k| h[k] = {} }
      end

      # Returns all the active/current assignments of this given process
      #
      # @return [Hash{Karafka::Routing::Topic => Array<Integer>}]
      #
      # @note Keep in mind, that those assignments can change any time, especially when working
      #   with multiple consumer groups or subscription groups.
      #
      # @note We return a copy because we modify internals and we do not want user to tamper with
      #   the data accidentally
      def current
        assignments = {}

        # Since the `@assignments` state can change during a rebalance, if we would iterate over
        # it exactly during state change, we would end up with the following error:
        #   RuntimeError: can't add a new key into hash during iteration
        @mutex.synchronize do
          @assignments.each do |topic, partitions|
            assignments[topic] = partitions.dup.freeze
          end
        end

        assignments.freeze
      end

      # Returns the generation counts for all partitions that have ever been assigned
      #
      # @return [Hash{Karafka::Routing::Topic => Hash{Integer => Integer}}] topic to partition
      #   generation mapping. Generation starts at 1 on first assignment and increments on each
      #   reassignment. Revoked partitions remain in the hash with their last generation value.
      #
      # @note Returns a frozen deep copy to prevent external mutation
      def generations
        result = {}

        @mutex.synchronize do
          @generations.each do |topic, partitions|
            result[topic] = partitions.dup.freeze
          end
        end

        result.freeze
      end

      # Returns the generation count for a specific topic-partition
      #
      # @param topic [Karafka::Routing::Topic]
      # @param partition [Integer]
      # @return [Integer] generation count (0 if never assigned, 1+ otherwise)
      def generation(topic, partition)
        @mutex.synchronize do
          @generations.dig(topic, partition) || 0
        end
      end

      # Clears all the assignments and generations
      def clear
        @mutex.synchronize do
          @assignments.clear
          @generations.clear
        end
      end

      # @return [String] thread-safe and lock-safe inspect implementation
      def inspect
        info = if @mutex.try_lock
          begin
            assignments = @assignments.dup.transform_keys(&:name).inspect
            "assignments=#{assignments}"
          ensure
            @mutex.unlock
          end
        else
          "busy"
        end

        "#<#{self.class.name} #{info}>"
      end

      # When client is under reset due to critical issues, remove all of its assignments as we will
      #   get a new set of assignments
      # @param event [Karafka::Core::Monitoring::Event]
      def on_client_reset(event)
        sg = event[:subscription_group]

        @mutex.synchronize do
          @assignments.delete_if do |topic, _partitions|
            topic.subscription_group.id == sg.id
          end
        end
      end

      # Handles events_poll notification to detect assignment loss
      # This is called regularly (every tick_interval) so we check if assignment was lost
      #
      # @param event [Karafka::Core::Monitoring::Event]
      # @note We can run the `#assignment_lost?` on each events poll because they happen once every
      #   5 seconds during processing plus prior to each messages poll. It takes
      #   0.6 microseconds per call.
      def on_client_events_poll(event)
        client = event[:caller]

        # Only clear assignments if they were actually lost
        return unless client.assignment_lost?

        # Cleaning happens the same way as with the consumer reset
        on_client_reset(event)
      end

      # Removes partitions from the current assignments hash
      #
      # @param event [Karafka::Core::Monitoring::Event]
      def on_rebalance_partitions_revoked(event)
        sg = event[:subscription_group]

        @mutex.synchronize do
          event[:tpl].to_h.each do |topic, partitions|
            topic = sg.topics.find(topic)

            @assignments[topic] -= partitions.map(&:partition)
            @assignments[topic].sort!
            # Remove completely topics for which we do not have any assignments left
            @assignments.delete_if { |_topic, cur_partitions| cur_partitions.empty? }
          end
        end
      end

      # # Adds partitions to the current assignments hash
      #
      # @param event [Karafka::Core::Monitoring::Event]
      def on_rebalance_partitions_assigned(event)
        sg = event[:subscription_group]

        @mutex.synchronize do
          event[:tpl].to_h.each do |topic, partitions|
            topic = sg.topics.find(topic)

            partitions.each do |partition|
              partition_id = partition.partition
              @generations[topic][partition_id] ||= 0
              @generations[topic][partition_id] += 1
            end

            @assignments[topic] += partitions.map(&:partition)
            @assignments[topic].sort!
          end
        end
      end
    end
  end
end
