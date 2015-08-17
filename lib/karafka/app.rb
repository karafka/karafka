module Karafka
  # App class
  class App
    class << self
      attr_writer :logger
      # Method which runs app
      def run
        Karafka::Connection::Consumer.new.call
      end

      # @return [Logger] logger that we want to use
      def logger
        @logger ||= ::Karafka::Logger.new(STDOUT).tap do |logger|
          logger.level = (ENV['KARAFKA_LOG_LEVEL'] || ::Logger::WARN).to_i
        end
      end

      # @return [Karafka::Config] config instance
      def config
        Config.config
      end

      # Sets up the whole configuration
      # @param [Block] block configuration block
      def setup(&block)
        Config.setup(&block)
      end
    end
  end
end
