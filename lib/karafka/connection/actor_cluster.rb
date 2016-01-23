module Karafka
  module Connection
    # A single connection cluster is responsible for listening to many routes
    # Each actor cluster will execute a separate celluloid thread
    class ActorCluster
      include Celluloid

      execute_block_on_receiver :fetch_loop

      # @param routes [Array<Karafka::Routing::Route>] array with all the routes that should be
      #   handled in this cluster
      def initialize(routes)
        @routes = routes
      end

      # Performs a constant check of each of the listeners for incoming messages and if any,
      #   will pass the block that should be evaluated
      # @param [Proc] block that should be executed for each incoming message
      def fetch_loop(block)
        loop do
          listeners.each do |listener|
            return true unless Karafka::App.running?

            listener.fetch(block)
          end
        end
      # This is the last protection layer before the actor crashes
      # If anything happens down the road - we should catch it here and just
      # rerun the whole loop while rebuilding all the listeners to reset
      # everything and make sure that this error does not affect actors
      # rubocop:disable RescueException
      rescue Exception => e
        # rubocop:enable RescueException
        Karafka.monitor.notice_error(self.class, e)
        @listeners = nil
        retry
      end

      private

      # @return [Array<Karafka::Connection::Listener>] array of listeners
      #   that allow us to fetch data.
      # @note Each listener listens to a single route
      def listeners
        @listeners ||= @routes.map do |route|
          Karafka::Connection::Listener.new(route)
        end
      end
    end
  end
end
