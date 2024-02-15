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
      def ensure_supported!
        return if supported?

        raise(
          Errors::UnsupportedOptionError,
          'Swarm mode not supported on this platform'
        )
      end

      # @return [Boolean] true if fork API and pidfd OS API are available, otherwise false
      def supported?
        ::Process.respond_to?(:fork) && Swarm::Pidfd.supported?
      end
    end
  end
end
