module Karafka
  # Class used to run the Karafka consumer and handle shutting down, restarting etc
  class Runner
    # @return [Karafka::Runner] runner instance
    def initialize
      @consumer = Karafka::Connection::Consumer.new
    end

    # Will loop and fetch any incoming messages
    # @note This will last forever if not interrupted
    def run
      loop do
        break if terminated?
        fetch
      end
    end

    private

    # Single fetch run with fatal error catching and logging
    # @note Single consumer consumes all the topics that we listen on
    def fetch
      Terminator.catch_signals { terminate }
      @consumer.fetch
    rescue => e
      Karafka.logger.fatal(e)
    ensure
      Terminator.reset_signals
    end

    def terminate
      @terminated = true
    end

    def terminated?
      @terminated
    end
  end
end
