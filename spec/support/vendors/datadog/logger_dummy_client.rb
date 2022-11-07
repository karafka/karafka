# frozen_string_literal: true

module Vendors
  module Datadog
    # Logger client that matches the basic `Datadog::Tracing` API.
    class LoggerDummyClient
      attr_reader :buffer, :errors

      def initialize
        @buffer = Concurrent::Array.new
        @errors = Concurrent::Array.new
      end

      # Store key trace
      # @param key [Object] key we want to start tracing
      def trace(key)
        @buffer << key
        self
      end

      # @return [Object] traced resource
      def resource
        self
      end

      # @param key [Object] assigned key
      # @return [Object] traced resource
      def resource=(key)
        @buffer << key
      end

      # @return [Object] traced resource
      def active_span
        self
      end

      # @return [Object] traced resource
      def current_span
        self
      end

      # @param error [Object] encountered error
      # @return [Object] traced resource
      def set_error(error)
        @errors << error
        self
      end

      # @return [Boolean]
      def present?
        true
      end

      # API compatibility hook
      def finish
        self
      end
    end
  end
end
