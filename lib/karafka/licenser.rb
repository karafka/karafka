# frozen_string_literal: true

module Karafka
  # Checks the license presence for pro and loads pro components when needed (if any)
  class Licenser
    # Location in the gem where we store the public key
    PUBLIC_KEY_LOCATION = File.join(Karafka.gem_root, "certs", "karafka-pro.pem")

    private_constant :PUBLIC_KEY_LOCATION

    class << self
      # Tries to load the license and yields if successful
      def detect
        # If license module is already fully defined, don't touch it
        # This allows users to define their own License module for testing/custom setups
        unless license_fully_defined?
          # Try safe approach first (no code execution)
          loaded = safe_load_license || fallback_require_license

          # If neither method succeeded, return false
          return false unless loaded
        end

        yield

        true
      rescue LoadError
        false
      end

      # Tries to prepare license and verifies it
      #
      # @param license_config [Karafka::Core::Configurable::Node] config related to the licensing
      def prepare_and_verify(license_config)
        # If license is not loaded, nothing to do
        return unless const_defined?("::Karafka::License")

        prepare(license_config)
        verify(license_config)
      end

      private

      # Check if License module and required methods are already defined
      # @return [Boolean]
      def license_fully_defined?
        return false unless const_defined?("::Karafka::License")

        # Check if the required methods exist
        ::Karafka::License.respond_to?(:token) &&
          ::Karafka::License.respond_to?(:version)
      end

      # Attempt to safely load license without executing gem code
      # @return [Boolean] true if successful, false otherwise
      def safe_load_license
        return false if const_defined?("::Karafka::License")

        spec = Gem::Specification.find_by_name("karafka-license")
        license_path = File.join(spec.gem_dir, "lib", "license.txt")
        version_path = File.join(spec.gem_dir, "lib", "version.txt")

        return false unless File.exist?(license_path)

        # Manually construct the module without executing code
        license_token = File.read(license_path)
        version_content = File.read(version_path)

        ::Karafka.const_set(:License, Module.new)
        ::Karafka::License.define_singleton_method(:token) { license_token }
        ::Karafka::License.define_singleton_method(:version) { version_content }

        true
      rescue Gem::MissingSpecError, Errno::ENOENT
        false
      end

      # Fallback to traditional require if safe method fails
      # @return [Boolean] true if successful, false otherwise
      def fallback_require_license
        return false if const_defined?("::Karafka::License")

        require("karafka-license")
        true
      rescue LoadError
        false
      end

      # @param license_config [Karafka::Core::Configurable::Node] config related to the licensing
      def prepare(license_config)
        license_config.token = Karafka::License.token
      end

      # Check license and setup license details (if needed)
      # @param license_config [Karafka::Core::Configurable::Node] config related to the licensing
      def verify(license_config)
        public_key = OpenSSL::PKey::RSA.new(File.read(PUBLIC_KEY_LOCATION))

        # We gsub and strip in case someone copy-pasted it as a multi line string
        formatted_token = license_config.token.strip.delete("\n").delete(" ")
        decoded_token = formatted_token.unpack1("m") # decode from base64

        begin
          data = public_key.public_decrypt(decoded_token)
        rescue OpenSSL::OpenSSLError
          data = nil
        end

        details = data ? JSON.parse(data) : raise_invalid_license_token(license_config)

        license_config.entity = details.fetch("entity")
      end

      # Raises an error with info, that used token is invalid
      # @param license_config [Karafka::Core::Configurable::Node]
      def raise_invalid_license_token(license_config)
        # We set it to false so `Karafka.pro?` method behaves as expected
        license_config.token = false

        raise(
          Errors::InvalidLicenseTokenError,
          <<~MSG.tr("\n", " ")
            License key you provided is invalid.
            Please reach us at contact@karafka.io or visit https://karafka.io to obtain a valid one.
          MSG
        )
      end
    end
  end
end
