module Karafka
  # Configurator for setting up all the Karafka framework details that are required to make it work
  # @note If you want to do some configurations after all of this is done, please add to
  #   karafka/config a proper file (needs to inherit from Karafka::Config::Base
  #   and implement setup method) after that everything will happen automatically
  # @see Karafka::Config::Base for more details about configurators api
  class Config
    class << self
      attr_accessor :config
    end

    # Available settings
    # option logger [Instance] logger that we want to use (defaults to Karafka::Logger)
    # option max_concurrency [Integer] how many threads that listen to Kafka can we have
    # option monitor [Instance] monitor instance that we want to use (defaults to Karafka::Monitor)
    # option name [String] current app name - used to provide default Kafka groups namespaces
    # option redis [Hash] redis options hash (url and optional parameters)
    # option wait_timeout [Integer] seconds that we will wait on a single topic for messages
    # option worker_timeout [Integer] how many seconds should we proceed stuff at Sidekiq
    # option zookeeper_hosts [Array] zookeeper hosts with ports where zookeeper servers are run
    # option kafka_hosts [Array] - optional - kafka hosts with ports (autodiscovered if missing)
    SETTINGS = %i(
      logger
      kafka_hosts
      max_concurrency
      monitor
      name
      redis
      wait_timeout
      worker_timeout
      zookeeper_hosts
    ).freeze

    SETTINGS.each do |attr_name|
      attr_accessor attr_name
    end

    # @return [Array<String>] all Kafka hosts (with porsts)
    # @note If hosts were not provided Karafka will ask Zookeeper for Kafka brokers. This is the
    #   default behaviour because it allows us to autodiscover new brokers and detect changes
    #   It might create a bigger load on Zookeeeper since on each failure it will reobtain brokers
    #   This is the reason why we don't use ||= syntax - it would assign and store brokers that
    #   might change during the runtime
    # @example
    #   kafka_hosts #=> ['172.17.0.2:9092', '172.17.0.4:9092']
    def kafka_hosts
      @kafka_hosts || Karafka::Connection::BrokerManager.new.all.map(&:url)
    end

    class << self
      # Configurating method
      # @yield Runs a block of code providing a config singleton instance to it
      # @yieldparam [Karafka::Config] Karafka config instance
      def setup
        self.config ||= new

        yield(config)
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
      # We configure internals first because other configurators rely on them
      Configurators::Internals.new(self).setup

      Configurators::Base.descendants.each do |klass|
        klass.new(self).setup
      end
    end
  end
end
