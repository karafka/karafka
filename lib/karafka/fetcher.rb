module Karafka
  # Class used to run the Karafka consumer and handle shutting down, restarting etc
  # @note Creating multiple fetchers will result in having multiple connections to the same
  #   topics, which means that if there are no partitions, it won't use them.
  class Fetcher
    # Starts listening on all the clusters asynchronously
    # Fetch loop should never end, which means that we won't create more actor clusters
    # so we don't have to terminate them
    def fetch_loop
      consume_with(:fetch_loop)
      actor_clusters.map(&:close)
    end

    # Starts consuming messages without a loop
    # It means, that it will consume messages for a given period of time and it will stop
    # This can be used to fetch messages from a console or any other process, without having
    # to start a Karafka server process.
    # @note If there are many messages, it might not consume all of them in a single run
    def fetch
      consume_with(:fetch)
      actor_clusters.map(&:close)
    end

    private

    # Consumes messages asynchronously using a given method
    # @note It uses Celluloid futures feature to wait for all the tasks to finish
    # @param method_name [Symbol] name of a method from an actor cluster that we want to use
    #   to consume messages
    def consume_with(method_name)
      futures = actor_clusters.map do |actor_cluster|
        actor_cluster.future.public_send(method_name, consumer)
      end

      futures.map(&:value)
    # If anything crashes here, we need to raise the error and crush the runner because it means
    # that something really bad happened
    rescue => e
      Karafka.monitor.notice_error(self.class, e)
      Karafka::App.stop!
      raise e
    end

    # @return [Array<Karafka::Connection::ActorCluster>] array with all the connection clusters
    # @note We cache actor clusters because in a consumer mode (without a server process), we have
    #   to use the same clusters with the same connections in order to consume from
    #   the same partitions
    def actor_clusters
      @actor_clusters ||= App
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
