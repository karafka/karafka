# frozen_string_literal: true

module Karafka
  # Class used to run the Karafka consumer and handle shutting down, restarting etc
  # @note Creating multiple fetchers will result in having multiple connections to the same
  #   topics, which means that if there are no partitions, it won't use them.
  class Fetcher
    # Starts listening on all the listeners asynchronously
    # Fetch loop should never end, which means that we won't create more actor clusters
    # so we don't have to terminate them
    def fetch_loop
      futures = listeners.map do |listener|
        listener.future.public_send(:fetch_loop, processor)
      end

      futures.map(&:value)
    # If anything crashes here, we need to raise the error and crush the runner because it means
    # that something really bad happened
    rescue => e
      Karafka.monitor.notice_error(self.class, e)
      Karafka::App.stop!
      raise e
    end

    private

    # @return [Array<Karafka::Connection::Listener>] listeners that will consume messages
    def listeners
      @listeners ||= App.consumers.map do |processor|
        Karafka::Connection::Listener.new(processor)
      end
    end

    # @return [Proc] proc that should be processed when a message arrives
    # @yieldparam message [Kafka::FetchedMessage] message from kafka (raw one)
    def processor
      lambda do |consumer_group_id, message|
        Karafka::Connection::MessageProcessor.process(consumer_group_id, message)
      end
    end
  end
end
