module Karafka
  # App class
  class App
    class << self
      # Method which runs app
      def run
        bind_on_sigint
        bind_on_sigquit
        start_supervised
      end

      # Sets up the whole configuration
      # @param [Block] block configuration block
      def setup(&block)
        Setup::Config.setup(&block)
        initialize!
      end

      # @return [Karafka::Config] config instance
      def config
        Setup::Config.config
      end

      # @return [Karafka::Routing::Builder] routes builder instance
      def routes
        Routing::Builder.instance
      end

      Status.instance_methods(false).each do |delegated|
        define_method(delegated) do
          Status.instance.public_send(delegated)
        end
      end

      # Methods that should be delegated to Karafka module
      %i(
        root env logger monitor
      ).each do |delegated|
        define_method(delegated) do
          Karafka.public_send(delegated)
        end
      end

      private

      # @return [Karafka::Process] process wrapper instance used to catch system signal calls
      def process
        Karafka::Process.instance
      end

      # What should happen when we decide to quit with sigint
      def bind_on_sigint
        process.on_sigint do
          stop!
          exit
        end
      end

      # What should happen when we decide to quit with sigquit
      def bind_on_sigquit
        process.on_sigquit do
          stop!
          exit
        end
      end

      # Starts Karafka with a supervision
      def start_supervised
        process.supervise do
          Karafka::Runner.new.run
          run!
          sleep
        end
      end
    end
  end
end
