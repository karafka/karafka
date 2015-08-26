module Karafka
  # App class
  class App
    class << self
      # Method which runs app
      def run
        Karafka.logger.info('Starting Karafka framework')
        Karafka.logger.info("Environment: #{Karafka.env}")
        Karafka.logger.info("Kafka hosts: #{config.kafka_hosts}")
        Karafka.logger.info("Zookeeper hosts: #{config.zookeeper_hosts}")
        run!
        Karafka::Runner.new.run
        sleep
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

      # Methods that should be delegated to Karafka::Status object
      %i(
        run! running? stop!
      ).each do |delegated|
        define_method(delegated) do
          Status.instance.public_send(delegated)
        end
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
        Celluloid.logger = Karafka.logger
      end
    end
  end
end
