module Karafka
  module Connection
    # Object representing a single Kafka broker (node) information
    # It is being built based on Zookeeper incoming json data
    # @note By using OpenStruct as a base we can use JSON data to map directly to object attributes
    class Broker < OpenStruct
      # @param json_data [String] string with JSON data describing broker
      def initialize(json_data)
        super JSON.parse(json_data)
      end

      # @return [String] host with port for this broker
      # @example
      #   broker.host #=> '172.16.0.1:9092'
      def host
        "#{super}:#{port}"
      end
    end
  end
end
