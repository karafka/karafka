# frozen_string_literal: true

module Karafka
  # Module used to check some constraints that cannot be easily defined by Bundler
  # At the moment we use it to ensure, that if Karafka is used, it operates with the expected
  # web ui version and that older versions of Web UI that would not be compatible with the API
  # changes in karafka are not used.
  #
  # We can make Web UI require certain karafka version range, but at the moment we do not have a
  # strict 1:1 release pattern matching those two.
  module Constraints
    class << self
      # Verifies that optional requirements are met.
      def verify!
        # Skip verification if web is not used at all
        return unless require_version('karafka/web')

        # All good if version higher than 0.9.0.rc3 because we expect 0.9.0.rc3 or higher
        return if version(Karafka::Web::VERSION) >= version('0.9.0.rc3')

        # If older web-ui used, we cannot allow it
        raise(
          Errors::DependencyConstraintsError,
          'karafka-web < 0.9.0 is not compatible with this karafka version'
        )
      end

      private

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
        ::Gem::Version.new(string)
      end
    end
  end
end
