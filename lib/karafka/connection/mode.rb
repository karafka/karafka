# frozen_string_literal: true

module Karafka
  module Connection
    # Represents the connection mode state of the Kafka client.
    # Encapsulates mode logic and provides a cleaner API for checking and setting connection modes,
    # removing the need for symbol comparisons throughout the connection management code.
    #
    # @note This class is used internally by the Client and is not part of the public API
    #
    # @example Check if client is in subscribe mode (internal usage)
    #   @mode.subscribe? #=> true
    #
    # @example Set the connection mode to assign (internal usage)
    #   @mode.assign!
    class Mode
      # Available connection modes for Kafka client
      # - :subscribe - client subscribes to topics and lets Kafka handle partition assignment
      # - :assign - client manually assigns specific topic partitions
      MODES = %i[
        subscribe
        assign
      ].freeze

      # @param mode [Symbol] initial connection mode (defaults to :subscribe)
      # @raise [ArgumentError] when invalid mode is provided
      def initialize(mode = :subscribe)
        self.mode = mode
      end

      # Define query and setter methods for each mode using meta-programming
      # This creates methods like: subscribe?, assign?
      # And bang methods like: subscribe!, assign!
      MODES.each do |mode_name|
        # @return [Boolean] true if the current mode matches this mode
        define_method("#{mode_name}?") do
          @mode == mode_name
        end

        # Sets the connection mode to this mode
        # @return [Symbol] the new mode
        define_method("#{mode_name}!") do
          self.mode = mode_name
        end
      end

      # @return [String] string representation of the current mode
      def to_s
        @mode.to_s
      end

      # @return [Symbol] symbol representation of the current mode
      def to_sym
        @mode
      end

      private

      # @param new_mode [Symbol] the new connection mode to set
      # @raise [ArgumentError] when invalid mode is provided
      def mode=(new_mode)
        if MODES.include?(new_mode)
          @mode = new_mode
        else
          raise(
            ArgumentError,
            "Invalid connection mode: #{new_mode}. Valid modes: #{MODES.join(', ')}"
          )
        end
      end
    end
  end
end
