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

      def initialize
        @last_checked_at = 0
        @mutex = Mutex.new
      end

      # Since there may be many statistics emitted from multiple listeners, we do not want to write
      # statuses that often. Instead we do it only once in a while which should be enough
      #
      # While this may provide a small lag in the orphaned detection, it does not really matter
      # as it will be picked up fast enough.
      # @param _event [Karafka::Core::Monitoring::Event]
      def on_statistics_emitted(_event)
        periodically do
          Kernel.exit!(orphaned_exit_code) if node.orphaned?

          node.healthy
        end
      end

      private

      # Wraps the logic with a mutex
      # @param block [Proc] code we want to run in mutex
      def synchronize(&block)
        @mutex.synchronize(&block)
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
