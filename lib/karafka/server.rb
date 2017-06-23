module Karafka
  # Karafka consuming server class
  class Server
    class << self
      # We need to store reference to all the consumers in the main server thread,
      # So we can have access to them later on and be able to stop them on exit
      attr_reader :consumers

      # Method which runs app
      def run
        @consumers = Concurrent::Array.new
        bind_on_sigint
        bind_on_sigquit
        bind_on_sigterm
        start_supervised
      end

      private

      # @return [Karafka::Process] process wrapper instance used to catch system signal calls
      def process
        Karafka::Process.instance
      end

      # What should happen when we decide to quit with sigint
      def bind_on_sigint
        process.on_sigint do
          Karafka::App.stop!
          consumers.map(&:stop)
          exit
        end
      end

      # What should happen when we decide to quit with sigquit
      def bind_on_sigquit
        process.on_sigquit do
          Karafka::App.stop!
          consumers.map(&:stop)
          exit
        end
      end

      # What should happen when we decide to quit with sigterm
      def bind_on_sigterm
        process.on_sigterm do
          Karafka::App.stop!
          consumers.map(&:stop)
          exit
        end
      end

      # Starts Karafka with a supervision
      # @note We don't need to sleep because Karafka::Fetcher is locking and waiting to
      # finish loop (and it won't happen until we explicitily want to stop)
      def start_supervised
        process.supervise do
          Karafka::App.run!
          Karafka::Fetcher.new.fetch_loop
        end
      end
    end
  end
end
