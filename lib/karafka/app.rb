module Karafka
  # App class
  class App
    class << self
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
    end
  end
end
