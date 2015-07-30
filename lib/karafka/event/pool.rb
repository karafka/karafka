module Karafka
  class Event
    # Raw poseidon connection pool
    module Pool
      extend SingleForwardable
      # Delegate directly to pool
      def_delegators :pool, :with

      class << self
        # @return [::ConnectionPool]
        def pool
          @pool ||= ConnectionPool.new(
            size: ::Karafka.config.connection_pool_size,
            timeout: ::Karafka.config.connection_pool_timeout
          ) do
            addresses = ::Karafka.config.kafka_ports.map do |port|
              "#{::Karafka.config.kafka_host}:#{port}"
            end

            Poseidon::Producer.new(addresses, object_id.to_s)
          end
        end
      end
    end
  end
end
