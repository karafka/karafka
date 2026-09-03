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

        @batch = App.subscription_groups.flat_map do |group, subscription_groups|
          # Share groups can be described in the routing but their runtime is not implemented yet.
          # We refuse to assemble listeners for them instead of silently doing nothing. Excluding
          # them (e.g. `--exclude_share_groups`) or not defining them lets the rest of the app run.
          if group.share_group?
            raise(
              Errors::ShareGroupsNotImplementedError,
              "Share group '#{group.name}' cannot be run yet - share group (KIP-932) runtime " \
              "support is not implemented. See the KIP-932 roadmap for progress."
            )
          end

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
      def each(&)
        @batch.each(&)
      end

      # @return [Array<Listener>] active listeners
      def active
        select(&:active?)
      end
    end
  end
end
