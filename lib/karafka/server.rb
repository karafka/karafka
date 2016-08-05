module Karafka
  # Karafka consuming server class
  class Server
    class << self
      # Method which runs app
      def run
        bind_on_sigint
        bind_on_sigquit
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
          exit
        end
      end

      # What should happen when we decide to quit with sigquit
      def bind_on_sigquit
        process.on_sigquit do
          Karafka::App.stop!
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
