# frozen_string_literal: true

# Vendors specific support components
module Vendors
  # Namespace for DD specific support classes
  module Datadog
    # Dummy statsd client that accumulates metrics that are added instead of sending them
    # This allows us not to be dependent on the statsd gem but also be able to test out the
    # integration
    class StatsdDummyClient
      attr_reader :buffer

      def initialize
        @buffer = Hash.new do |buffer, dd_method|
          buffer[dd_method] = Hash.new do |key_scope, metric|
            key_scope[metric] = []
          end
        end
      end

      %i[
        count
        histogram
        gauge
        increment
        decrement
      ].each do |method_name|
        define_method method_name do |metric, value = nil, details = {}|
          @buffer[method_name][metric] << [value, details]
        end
      end
    end
  end
end
