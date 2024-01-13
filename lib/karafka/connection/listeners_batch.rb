# frozen_string_literal: true

module Karafka
  module Connection
    # Abstraction layer around listeners batch.
    class ListenersBatch
      include Enumerable

      # @param jobs_queue [JobsQueue]
      # @return [ListenersBatch]
      def initialize(jobs_queue)
        # We need one scheduler for all the listeners because in case of complex schedulers, they
        # should be able to distribute work whenever any work is done in any of the listeners
        scheduler = App.config.internal.processing.scheduler_class.new(jobs_queue)

        @batch = App.subscription_groups.flat_map do |_consumer_group, subscription_groups|
          subscription_groups.map do |subscription_group|
            Connection::Listener.new(
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

      # @return [Array<Listener>] active listeners
      def active
        select(&:active?)
      end
    end
  end
end
