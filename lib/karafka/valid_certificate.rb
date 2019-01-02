# frozen_string_literal: true

module Karafka
  # Validates certificate
  module ValidCertificate
    class << self
      # Validates certificate
      #
      # @param certificate [String] certificate sting
      def call(certificate)
        OpenSSL::X509::Certificate.new(certificate)
        true
      rescue OpenSSL::X509::CertificateError
        false
      end
    end
  end
end
