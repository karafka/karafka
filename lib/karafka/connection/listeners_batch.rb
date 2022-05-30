# frozen_string_literal: true

module Karafka
  module Connection
    # Abstraction layer around listeners batch.
    class ListenersBatch
      include Enumerable

      # @param jobs_queue [JobsQueue]
      # @return [ListenersBatch]
      def initialize(jobs_queue)
        @batch = App.subscription_groups.map do |subscription_group|
          Connection::Listener.new(subscription_group, jobs_queue)
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
