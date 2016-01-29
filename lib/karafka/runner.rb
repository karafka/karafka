module Karafka
  # Class used to run the Karafka consumer and handle shutting down, restarting etc
  class Runner
    # Starts listening on all the clusters asynchronously
    def run
      actor_clusters.each do |actor_cluster|
        actor_cluster.async.fetch_loop(consumer)
      end
    rescue => e
      Karafka.monitor.notice_error(self.class, e)
      Karafka::App.stop!
      raise e
    end

    private

    # @return [Array<Karafka::Connection::ActorCluster>] array with all the connection clusters
    def actor_clusters
      App
        .routes
        .each_slice(slice_size)
        .map do |chunk|
          Karafka::Connection::ActorCluster.new(chunk)
        end
    end

    # @return [Integer] number of topics that we want to listen to per thread
    # @note For smaller amount of controllers it would be the best to number of controllers
    #   to match number of threads - that way it could consume messages in "real" time
    def slice_size
      size = App.routes.size / Karafka::App.config.max_concurrency
      size < 1 ? 1 : size
    end

    # @return [Proc] proc that should be processed when a message arrives
    # @yieldparam message [Poseidon::FetchedMessage] message from poseidon (raw one)
    def consumer
      lambda do |message|
        Karafka::Connection::Consumer.new.consume(message)
      end
    end
  end
end
