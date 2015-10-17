module Karafka
  # App class
  class App
    class << self
      # Method which runs app
      def run
        initialize!

        monitor.on_sigint do
          stop!
          exit
        end

        monitor.on_sigquit do
          stop!
          exit
        end

        monitor.supervise do
          Karafka::Runner.new.run
          run!
          sleep
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

      Status.instance_methods(false).each do |delegated|
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

      # @return [Karafka::Monitor] monitor instance used to catch system signal calls
      def monitor
        Karafka::Monitor.instance
      end

      # Everything that should be initialized after the setup
      def after_setup
        Karafka::Worker.timeout = config.worker_timeout
        Karafka::Worker.logger = Karafka.logger
        Celluloid.logger = Karafka.logger
        configure_sidekiq
      end

      # Configure sidekiq client and server
      def configure_sidekiq
        Sidekiq.configure_client do |sidekiq_config|
          sidekiq_config.redis = {
            url: config.redis_url,
            namespace: config.redis_namespace || config.name,
            size: config.concurrency
          }
        end

        Sidekiq.configure_server do |sidekiq_config|
          # We don't set size for the server - this will be set automatically based
          # on the Sidekiq concurrency level (Sidekiq not Karafkas)
          sidekiq_config.redis = {
            url: config.redis_url,
            namespace: config.redis_namespace || config.name
          }
        end
      end
    end
  end
end
