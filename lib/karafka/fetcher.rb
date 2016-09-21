module Karafka
  # Class used to run the Karafka consumer and handle shutting down, restarting etc
  # @note Creating multiple fetchers will result in having multiple connections to the same
  #   topics, which means that if there are no partitions, it won't use them.
  class Fetcher
    def fetch_loop
      futures = listeners.map do |listener|
        listener.future.public_send(:fetch_loop, consumer)
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

    def listeners
      @listeners ||= App.routes.each.map do |route|
        Karafka::Connection::Listener.new(route)
      end
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
