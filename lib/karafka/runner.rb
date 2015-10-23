module Karafka
  # Class used to run the Karafka consumer and handle shutting down, restarting etc
  class Runner
    # Starts listening on all the clusters asynchronously
    def run
      clusters.each do |cluster|
        cluster.async.fetch_loop(consumer)
      end
    rescue => e
      Karafka::App.stop!
      Karafka.logger.fatal(e)
      raise e
    end

    private

    # @return [Array<Karafka::Connection::ActorCluster>] array with all the connection clusters
    def clusters
      Karafka::Routing::Mapper
        .controllers
        .each_slice(slice_size)
        .map do |chunk|
          Karafka::Connection::ActorCluster.new(chunk)
        end
    end

    # @return [Integer] number of topics that we want to listen to per thread
    # @note For smaller amount of controllers it would be the best to number of controllers
    #   to match number of threads - that way it could consume messages in "real" time
    def slice_size
      controllers_length = Karafka::Routing::Mapper.controllers.length
      size = controllers_length / Karafka::App.config.concurrency
      size < 1 ? 1 : size
    end

    # @return [Proc] proc that should be processed when a messaga arrives
    # @yieldparam controller [Karafka::BaseController] descendant of the base controller
    # @yieldparam message [Poseidon::FetchedMessage] message from poseidon (raw one)
    def consumer
      lambda do |controller, message|
        Karafka::Connection::Consumer.new.consume(controller, message)
      end
    end
  end
end
