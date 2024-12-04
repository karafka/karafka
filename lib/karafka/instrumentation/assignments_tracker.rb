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

      def initialize
        @mutex = Mutex.new
        @assignments = Hash.new { |hash, key| hash[key] = [] }
      end

      # Returns all the active/current assignments of this given process
      #
      # @return [Hash<Karafka::Routing::Topic, Array<Integer>>]
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

      # Clears all the assignments
      def clear
        @mutex.synchronize do
          @assignments.clear
        end
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

            @assignments[topic] += partitions.map(&:partition)
            @assignments[topic].sort!
          end
        end
      end
    end
  end
end
