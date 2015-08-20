module Karafka
  # Configurator for setting up delivery details
  class Config
    class << self
      attr_accessor :config
    end
    # Available settings
    # @option receive_events [Boolean] boolean value to define whether events should be received
    # option zookeeper_hosts [Array] zookeeper hosts with ports where zookeeper servers are run
    # option kafka_hosts [Array] kafka hosts with ports where kafka servers are run
    #
    SETTINGS = %i(
      zookeeper_hosts
      kafka_hosts
      worker_timeout
    )

    SETTINGS.each do |attr_name|
      attr_accessor attr_name
    end

    # Configurating method
    def self.setup(&block)
      self.config = new

      block.call(config)
      config.freeze
    end
  end
end
