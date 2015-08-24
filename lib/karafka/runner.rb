module Karafka
  # Class used to run the Karafka consumer and handle shutting down, restarting etc
  class Runner
    # @return [Karafka::Runner] runner instance
    def initialize
      @consumer = Karafka::Connection::Consumer.new
      @terminator = Terminator.new
    end

    # Will loop and fetch any incoming messages
    # @note This will last forever if not terminated
    def run
      loop do
        break if @terminator.terminated?
        fetch
      end
    end

    private

    # Single fetch run with fatal error catching and logging
    # @note Single consumer consumes all the topics that we listen on
    #   Method ignore terminator signals
    def fetch
      @terminator.catch_signals { @consumer.fetch }
    rescue => e
      Karafka.logger.fatal(e)
    end
  end
end
