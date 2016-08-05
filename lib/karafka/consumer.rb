module Karafka
  # Karafka consuming client that can be used without a standalone server to consume messages
  # @note It will consume part of messages if there are many of them
  # @example Consume messages
  #   Karafka::Consumer.run
  class Consumer
    class << self
      # Method which allows us to consume (and stop) messages
      def run
        semaphore.synchronize do
          Karafka::App.run!
          fetcher.fetch
          Karafka::App.stop!
        end
      end

      private

      # @return [::Mutex] mutex object to make sure that only one consumer runs in a process
      #   at the same time
      def semaphore
        @semaphore ||= Mutex.new
      end

      # @return [Karafka::Fetcher] fetcher that is responsible for consuming messages
      def fetcher
        @fetcher ||= Fetcher.new
      end
    end
  end
end
