module Karafka
  # Configurator for setting up delivery details
  class Config
    class << self
      attr_accessor :config
    end
    # Available settings
    # @option connection_pool_size [Fixnum] The number of connections to pool.
    # @option connection_pool_timeout [Fixnum] Amount of time in seconds to wait for a connection
    #         if none currently available.
    # @option kafka_ports [Array] the ports of kafka brokers
    # @option kafka_host [String] the host of kafka server
    # @option send_events [Boolean] boolean value to define whether events should be sent
    # option zookeeper_hosts [Array] zookeeper hosts with ports where zookeeper servers are run
    # option kafka_hosts [Array] kafka hosts with ports where kafka servers are run
    #
    SETTINGS = %i(
      connection_pool_size
      connection_pool_timeout
      kafka_ports
      kafka_host
      send_events
      zookeeper_hosts
      kafka_hosts
    )

    SETTINGS.each do |attr_name|
      attr_accessor attr_name

      # @return [Boolean] is given command enabled
      define_method :"#{attr_name}?" do
        public_send(attr_name) == true
      end
    end

    # Configurating method
    def self.configure(&block)
      self.config = new

      block.call(config)
      config.freeze
    end
  end
end
