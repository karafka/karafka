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

        after_setup
      end

      # Methods that should be delegated to Karafka module
      %i(
        root env
      ).each do |delegated|
        define_method(delegated) do
          Karafka.public_send(delegated)
        end
      end

      private

      # Everything that should be initialized after the setup
      def after_setup
        Karafka::Worker.timeout = config.worker_timeout
      end
    end
  end
end
