# frozen_string_literal: true

module Karafka
  module Connection
    # Abstraction layer around listeners batch.
    class ListenersBatch
      include Enumerable

      attr_reader :coordinators

      # @param jobs_queue [JobsQueue]
      # @param scheduler [Karafka::Processing::Scheduler] scheduler we want to use
      # @return [ListenersBatch]
      def initialize(jobs_queue, scheduler)
        @coordinators = []

        @batch = App.subscription_groups.flat_map do |_consumer_group, subscription_groups|
          consumer_group_coordinator = Connection::ConsumerGroupCoordinator.new(
            subscription_groups.size
          )

          @coordinators << consumer_group_coordinator

          subscription_groups.map do |subscription_group|
            Connection::Listener.new(
              consumer_group_coordinator,
              subscription_group,
              jobs_queue,
              scheduler
            )
          end
        end
      end

      # Iterates over available listeners and yields each listener
      # @param block [Proc] block we want to run
      def each(&block)
        @batch.each(&block)
      end
    end
  end
end
