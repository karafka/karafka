# frozen_string_literal: true

module Vendors
  # Appsignal related spec code
  module Appsignal
    # Dummy client for Appsignal so we do not have to get appsignal gem involved here
    class DummyClient
      attr_reader :buffer

      def initialize
        @buffer = Hash.new do |buffer, appsignal_method|
          buffer[appsignal_method] = Hash.new do |key_scope, metric|
            key_scope[metric] = []
          end
        end
      end

      # Fakes a transaction start
      #
      # @param action_name [String]
      def start_transaction(action_name)
        @buffer[:start_transaction][action_name] << true
      end

      # Fakes a transaction stop
      def stop_transaction
        @buffer[:stop_transaction][0] << true
      end

      # Assigns the metadata
      # @param metadata [Hash]
      def metadata=(metadata)
        @buffer[:metadata][0] << metadata
      end

      # Buffers the error
      #
      # @param error [Object]
      def send_error(error)
        @buffer[:errors][0] << error
      end

      %i[
        count
        gauge
      ].each do |method_name|
        define_method method_name do |metric, value = nil, details = {}|
          @buffer[method_name][metric] << [value, details]
        end
      end
    end
  end
end
