# frozen_string_literal: true

module Vendors
  module NewRelic
    # Dummy New Relic client that accumulates recorded metrics instead of sending them.
    # Assign an instance to `config.client` to test the listener without a real NR agent.
    class DummyClient
      attr_reader :buffer

      def initialize
        @buffer = Hash.new { |h, k| h[k] = [] }
      end

      # @param name [String] metric name
      # @param value [Numeric] metric value
      def record_metric(name, value)
        @buffer[name] << value
      end
    end
  end
end
