# frozen_string_literal: true

module Karafka
  module Swarm
    # Simple listener for swarm nodes that:
    #   - reports once in a while to make sure that supervisor is aware we do not hang
    #   - makes sure we did not become an orphan and if so, exits
    class LivenessListener
      include Karafka::Core::Helpers::Time
      include Helpers::ConfigImporter.new(
        node: %i[swarm node],
        liveness_interval: %i[internal swarm liveness_interval],
        orphaned_exit_code: %i[internal swarm orphaned_exit_code]
      )

      # Initializes the liveness listener
      def initialize
        @last_checked_at = 0
        @mutex = Mutex.new
      end

      # Report from the fetch loop at the top of each iteration
      # @param _event [Karafka::Core::Monitoring::Event]
      def on_connection_listener_fetch_loop(_event)
        report_liveness
      end

      # Report from events poll so liveness works during long processing.
      # This event fires periodically during wait even when the listener is blocked on consumer
      # jobs, preventing the supervisor from killing the node.
      # @param _event [Karafka::Core::Monitoring::Event]
      def on_client_events_poll(_event)
        report_liveness
      end

      private

      # Reports liveness to the supervisor periodically
      def report_liveness
        periodically do
          Kernel.exit!(orphaned_exit_code) if node.orphaned?

          node.healthy
        end
      end

      # Wraps the logic with a mutex
      def synchronize(&)
        @mutex.synchronize(&)
      end

      # Runs requested code once in a while
      def periodically
        return if monotonic_now - @last_checked_at < liveness_interval

        synchronize do
          @last_checked_at = monotonic_now

          yield
        end
      end
    end
  end
end
