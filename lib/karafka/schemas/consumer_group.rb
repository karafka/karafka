# frozen_string_literal: true

module Karafka
  module Schemas
    # Schema for single full route (consumer group + topics) validation.
    ConsumerGroup = Dry::Validation.Schema do
      # Valid uri schemas of Kafka broker url
      # The ||= is due to the behavior of require_all that resolves dependencies
      # but sometimes loads things twice
      URI_SCHEMES ||= %w[kafka kafka+ssl plaintext ssl].freeze

      # Available sasl scram mechanism of authentication (plus nil)
      SASL_SCRAM_MECHANISMS ||= %w[sha256 sha512].freeze

      configure do
        config.messages_file = File.join(Karafka.gem_root, 'config', 'errors.yml')

        # Uri validator to check if uri is in a Karafka acceptable format
        # @param uri [String] uri we want to validate
        # @return [Boolean] true if it is a valid uri, otherwise false
        def broker_schema?(uri)
          uri = URI.parse(uri)
          URI_SCHEMES.include?(uri.scheme) && uri.port
        rescue URI::InvalidURIError
          false
        end

        # Validates private key from a string
        #
        # @param private_key [String] private key string
        #
        # @return [Boolean] true if it is a valid private key, otherwise false
        def valid_private_key?(private_key)
          OpenSSL::PKey::RSA.new(private_key)
          true
        rescue OpenSSL::PKey::RSAError
          false
        end

        # Validates certificate from string
        #
        # @param certificate [String] certificate string
        #
        # @return [Boolean] true if it is a valid certificate, otherwise false
        def valid_certificate?(certificate)
          OpenSSL::X509::Certificate.new(certificate)
          true
        rescue OpenSSL::X509::CertificateError
          false
        end

        # Validates certificate from path
        #
        # @param file_path [String] path to certificate
        #
        # @return [Boolean] true if it is a valid certificate, otherwise false
        def valid_certificate_from_path?(file_path)
          File.exist?(file_path) && valid_certificate?(File.read(file_path))
        end
      end

      required(:id).filled(:str?, format?: Karafka::Schemas::TOPIC_REGEXP)
      required(:seed_brokers).filled { each(:broker_schema?) }
      required(:session_timeout).filled { int? | float? }
      required(:pause_timeout) { none? | ((int? | float?) & gteq?(0)) }
      required(:pause_max_timeout) { none? | ((int? | float?) & gteq?(0)) }
      required(:pause_exponential_backoff).filled(:bool?)
      required(:offset_commit_interval) { int? | float? }
      required(:offset_commit_threshold).filled(:int?)
      required(:offset_retention_time) { none?.not > int? }
      required(:heartbeat_interval).filled { (int? | float?) & gteq?(0) }
      required(:fetcher_max_queue_size).filled(:int?, gt?: 0)
      required(:connect_timeout).filled { (int? | float?) & gt?(0) }
      required(:reconnect_timeout).filled { (int? | float?) & gteq?(0) }
      required(:socket_timeout).filled { (int? | float?) & gt?(0) }
      required(:min_bytes).filled(:int?, gt?: 0)
      required(:max_bytes).filled(:int?, gt?: 0)
      required(:max_wait_time).filled { (int? | float?) & gteq?(0) }
      required(:batch_fetching).filled(:bool?)
      required(:topics).filled { each { schema(ConsumerGroupTopic) } }

      # If the exponential backoff is on, the max pause timeout needs to be equal or
      # bigger than the default pause timeout from which we start
      validate(
        max_timeout_size_for_exponential: %i[
          pause_timeout
          pause_max_timeout
          pause_exponential_backoff
        ]
      ) do |pause_timeout, pause_max_timeout, pause_exponential_backoff|
        pause_exponential_backoff ? pause_timeout.to_i <= pause_max_timeout.to_i : true
      end

      # Max wait time cannot exceed socket_timeout - wouldn't make sense
      rule(
        max_wait_time_limit: %i[max_wait_time socket_timeout]
      ) do |max_wait_time, socket_timeout|
        socket_timeout.int? > max_wait_time.lteq?(value(:socket_timeout))
      end

      %i[
        ssl_ca_cert
        ssl_ca_cert_file_path
        ssl_client_cert
        ssl_client_cert_key
        ssl_client_cert_chain
        ssl_client_cert_key_password
        sasl_gssapi_principal
        sasl_gssapi_keytab
        sasl_plain_authzid
        sasl_plain_username
        sasl_plain_password
        sasl_scram_username
        sasl_scram_password
      ].each do |encryption_attribute|
        optional(encryption_attribute).maybe(:str?)
      end

      optional(:ssl_ca_certs_from_system).maybe(:bool?)
      optional(:sasl_over_ssl).maybe(:bool?)

      # It's not with other encryptions as it has some more rules
      optional(:sasl_scram_mechanism)
        .maybe(:str?, included_in?: Karafka::Schemas::SASL_SCRAM_MECHANISMS)

      rule(
        ssl_client_cert_with_ssl_client_cert_key: %i[
          ssl_client_cert
          ssl_client_cert_key
        ]
      ) do |ssl_client_cert, ssl_client_cert_key|
        ssl_client_cert.filled? > ssl_client_cert_key.filled?
      end

      rule(
        ssl_client_cert_key_with_ssl_client_cert: %i[
          ssl_client_cert
          ssl_client_cert_key
        ]
      ) do |ssl_client_cert, ssl_client_cert_key|
        ssl_client_cert_key.filled? > ssl_client_cert.filled?
      end

      rule(
        ssl_client_cert_chain_with_ssl_client_cert: %i[
          ssl_client_cert
          ssl_client_cert_chain
        ]
      ) do |ssl_client_cert, ssl_client_cert_chain|
        ssl_client_cert_chain.filled? > ssl_client_cert.filled?
      end

      rule(
        ssl_client_cert_chain_with_ssl_client_cert_key: %i[
          ssl_client_cert_chain
          ssl_client_cert_key
        ]
      ) do |ssl_client_cert_chain, ssl_client_cert_key|
        ssl_client_cert_chain.filled? > ssl_client_cert_key.filled?
      end

      rule(
        ssl_client_cert_key_password_with_ssl_client_cert_key: %i[
          ssl_client_cert_key_password
          ssl_client_cert_key
        ]
      ) do |ssl_client_cert_key_password, ssl_client_cert_key|
        ssl_client_cert_key_password.filled? > ssl_client_cert_key.filled?
      end

      rule(ssl_ca_cert_valid_ceritificate: %i[ssl_ca_cert]) do |ssl_ca_cert|
        ssl_ca_cert.filled? > ssl_ca_cert.valid_certificate?
      end

      rule(
        ssl_ca_cert_file_path_valid_ceritificate: %i[ssl_ca_cert_file_path]
      ) do |ssl_ca_cert_file_path|
        ssl_ca_cert_file_path.filled? > ssl_ca_cert_file_path.valid_certificate_from_path?
      end

      rule(
        ssl_client_cert_valid_ceritificate: %i[ssl_client_cert]
      ) do |ssl_client_cert|
        ssl_client_cert.filled? > ssl_client_cert.valid_certificate?
      end

      rule(
        ssl_client_cert_key_valid_private_key: %i[ssl_client_cert_key]
      ) do |ssl_client_cert_key|
        ssl_client_cert_key.filled? > ssl_client_cert_key.valid_private_key?
      end

      rule(
        ssl_client_cert_chain_ceritificate: %i[ssl_client_cert_chain]
      ) do |ssl_client_cert_chain|
        ssl_client_cert_chain.filled? > ssl_client_cert_chain.valid_certificate?
      end
    end
  end
end
