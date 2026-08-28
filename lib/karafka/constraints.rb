# frozen_string_literal: true

module Karafka
  # Module used to check optional requirements (constraints) that cannot be easily defined by
  # Bundler. Constraints are registered under one of two phases and verified centrally, so all
  # environment requirements live and surface in one place:
  #
  # - `:load` - verified when karafka itself is required, for requirements independent of the
  #   configuration (like ecosystem gems version compatibility)
  # - `:config` - verified during `Karafka::App.setup` right after the configuration is
  #   validated, for requirements that depend on what features are actually enabled (features
  #   register those themselves, keeping their specifics out of this generic module)
  module Constraints
    # Phases in which constraints can be verified
    PHASES = %i[load config].freeze

    private_constant :PHASES

    class << self
      # Registers a constraint for verification. Registrations are keyed by name, so
      # re-registration (e.g. when setup runs multiple times in tests) overwrites a previous
      # one instead of accumulating duplicates.
      #
      # @param name [Symbol] unique constraint name
      # @param phase [Symbol] `:load` or `:config`
      # @param block [Proc] verification receiving the config node (`nil` in the `:load`
      #   phase) and expected to raise `Karafka::Errors::DependencyConstraintsError` when the
      #   requirement is not met
      def register(name, phase:, &block)
        raise(Errors::UnsupportedCaseError, phase) unless PHASES.include?(phase)

        constraints[phase][name] = block
      end

      # Verifies all the constraints registered for a given phase
      #
      # @param phase [Symbol] `:load` or `:config`
      # @param config [Karafka::Core::Configurable::Node, nil] config node for the `:config`
      #   phase, `nil` in the `:load` phase
      def verify!(phase = :load, config = nil)
        raise(Errors::UnsupportedCaseError, phase) unless PHASES.include?(phase)

        constraints[phase].each_value { |constraint| constraint.call(config) }
      end

      private

      # @return [Hash{Symbol => Hash{Symbol => Proc}}] registered constraints per phase
      def constraints
        @constraints ||= PHASES.to_h { |phase| [phase, {}] }
      end

      # Requires given version file from a gem location
      # @param version_location [String]
      # @return [Boolean] true if it was required or false if not reachable
      def require_version(version_location)
        require "#{version_location}/version"

        true
      rescue LoadError
        false
      end

      # Builds a version object for comparing
      # @param string [String]
      # @return [::Gem::Version]
      def version(string)
        Gem::Version.new(string)
      end
    end

    # If Karafka is used with the Web UI, it needs to be in a version compatible with the API
    # changes in this karafka version. We can make Web UI require a certain karafka version
    # range, but at the moment we do not have a strict 1:1 release pattern matching those two.
    register(:karafka_web_version, phase: :load) do |_config|
      # Skip verification if web is not used at all
      next unless require_version("karafka/web")

      # All good if version higher than 1.0.0.rc1 because we expect 1.0.0.rc2 or higher
      next if version(Karafka::Web::VERSION) >= version("1.0.0.rc2")

      # If older web-ui used, we cannot allow it
      raise(
        Errors::DependencyConstraintsError,
        "karafka-web < 1.0.0.rc2 is not compatible with this karafka version"
      )
    end
  end
end
