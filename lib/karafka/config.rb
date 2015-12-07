module Karafka
  # Configurator for setting up all the Karafka framework details that are required to make it work
  # @note If you want to do some configurations after all of this is done, please add to
  #   karafka/config a proper file (needs to inherit from Karafka::Config::BaseComponent) after
  #   that everything will happen automatically
  # @see Karafka::Config::BaseComponent for more details about configurators api
  class Config
    class << self
      attr_accessor :config
    end
    # Available settings
    # option zookeeper_hosts [Array] zookeeper hosts with ports where zookeeper servers are run
    # option kafka_hosts [Array] kafka hosts with ports where kafka servers are run
    # option redis [Hash] redis options hash (url and optional parameters)
    # option worker_timeout [Integer] how many seconds should we proceed stuff at Sidekiq
    # option concurrency [Integer] how many threads that listen to incoming connections can we have
    # option name [String] current app name - used to provide default Kafka groups namespaces
    SETTINGS = %i(
      zookeeper_hosts
      kafka_hosts
      redis
      worker_timeout
      concurrency
      name
    )

    SETTINGS.each do |attr_name|
      attr_accessor attr_name
    end

    class << self
      # Configurating method
      def setup(&block)
        self.config ||= new

        block.call(config)
        # This is a class method and we don't want to make setup_components
        # public but we still want to invoke it here
        config.send :setup_components
        config.freeze
      end
    end

    private

    # Everything that should be initialized after the setup
    # Components are in karafka/config directory and are all loaded one by one
    # If you want to configure a next component, please add a proper file to config dir
    def setup_components
      Configurators::Base.descendants.each do |klass|
        klass.new(self).setup
      end
    end
  end
end
