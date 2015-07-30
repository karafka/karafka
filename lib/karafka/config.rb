module Karafka
  class Config
    class << self
      attr_accessor :config
    end

    SETTINGS = %i(
      connection_pool_size
      connection_pool_timeout
      kafka_ports
      kafka_host
      send_events
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
