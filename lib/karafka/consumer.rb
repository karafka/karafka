module Karafka
  # Karafka consuming client that can be used without a standalone server to consume messages
  class Consumer
    class << self
      # Method which runs app
      def run
        semaphore.synchronize do
          Karafka::App.run!
          fetcher.fetch
          Karafka::App.stop!
        end
      end

      private

      def semaphore
        @semaphore ||= Mutex.new
      end

      def fetcher
        @fetcher ||= Fetcher.new
      end
    end
  end
end
