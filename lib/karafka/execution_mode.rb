# frozen_string_literal: true

module Karafka
  # Represents the execution mode state of the Karafka server.
  # Provides a cleaner API for checking and setting execution modes, encapsulating the mode logic
  # and removing the need for symbol comparisons throughout the codebase.
  #
  # @example Check if running in swarm mode
  #   Server.execution_mode.swarm? #=> false
  #
  # @example Set the execution mode to embedded
  #   Server.execution_mode.embedded!
  class ExecutionMode
    # Available execution modes for Karafka server
    # - :standalone - regular karafka consumer process
    # - :embedded - embedded in a different process and not supervised
    # - :supervisor - swarm supervisor process
    # - :swarm - one of swarm processes
    MODES = %i[
      standalone
      embedded
      supervisor
      swarm
    ].freeze

    # @param mode [Symbol] initial execution mode (defaults to :standalone)
    # @raise [ArgumentError] when invalid mode is provided
    def initialize(mode = :standalone)
      self.mode = mode
    end

    # Define query and setter methods for each mode using meta-programming
    # This creates methods like: standalone?, embedded?, swarm?, etc.
    # And bang methods like: standalone!, embedded!, swarm!, etc.
    MODES.each do |mode_name|
      # @return [Boolean] true if the current mode matches this mode
      define_method("#{mode_name}?") do
        @mode == mode_name
      end

      # Sets the execution mode to this mode
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

    # Compares the execution mode with another object.
    # Supports comparison with symbols, strings, and other ExecutionMode instances
    # for backward compatibility with existing code.
    #
    # @param other [Symbol, String, ExecutionMode] object to compare with
    # @return [Boolean] true if the modes are equivalent
    #
    # @example Compare with symbol
    #   execution_mode == :standalone #=> true
    #
    # @example Compare with string
    #   execution_mode == 'standalone' #=> true
    #
    # @example Compare with another ExecutionMode
    #   execution_mode == other_mode #=> true/false
    def ==(other)
      case other
      when Symbol
        @mode == other
      when String
        @mode.to_s == other
      when ExecutionMode
        @mode == other.to_sym
      else
        false
      end
    end

    private

    # @param new_mode [Symbol] the new execution mode to set
    # @raise [ArgumentError] when invalid mode is provided
    def mode=(new_mode)
      if MODES.include?(new_mode)
        @mode = new_mode
      else
        raise(
          ArgumentError,
          "Invalid execution mode: #{new_mode}. Valid modes: #{MODES.join(', ')}"
        )
      end
    end
  end
end
