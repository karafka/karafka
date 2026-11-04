# frozen_string_literal: true

module Karafka
  # Namespace for the Swarm capabilities.
  #
  # Karafka in the swarm mode will fork additional processes and use the parent process as a
  # supervisor. This capability allows to run multiple processes alongside but saves some memory
  # due to CoW.
  module Swarm
    class << self
      # Raises an error if swarm is not supported on a given platform
      #
      # @raise [Errors::UnsupportedOptionError] with the Ruby engine name when it has no fork
      def ensure_supported!
        return if supported?

        raise(Errors::UnsupportedOptionError, RUBY_ENGINE)
      end

      # @return [Boolean] true if fork API is available, otherwise false
      def supported?
        ::Process.respond_to?(:fork)
      end
    end
  end
end
