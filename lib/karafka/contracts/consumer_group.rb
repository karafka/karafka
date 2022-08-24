# frozen_string_literal: true

module Karafka
  module Contracts
    # Contract for single full route (consumer group + topics) validation.
    class ConsumerGroup < Dry::Validation::Contract
      config.messages.load_paths << File.join(Karafka.gem_root, 'config', 'errors.yml')

      # Valid uri schemas of Kafka broker url
      # The ||= is due to the behavior of require_all that resolves dependencies
      # but sometimes loads things twice
      URI_SCHEMES ||= %w[kafka kafka+ssl plaintext ssl].freeze

      # Available sasl scram mechanism of authentication (plus nil)
      SASL_SCRAM_MECHANISMS ||= %w[sha256 sha512].freeze

      # Internal contract for sub-validating topics schema
      TOPIC_CONTRACT = ConsumerGroupTopic.new.freeze

      private_constant :TOPIC_CONTRACT

      params do
        required(:id).filled(:str?, format?: Karafka::Contracts::TOPIC_REGEXP)
        required(:topics).value(:array, :filled?)
        required(:seed_brokers).value(:array, :filled?)
        required(:session_timeout).filled { int? | float? }
        required(:pause_timeout).maybe(%i[integer float]) { filled? > gteq?(0) }
        required(:pause_max_timeout).maybe(%i[integer float]) { filled? > gteq?(0) }
        required(:pause_exponential_backoff).filled(:bool?)
        required(:offset_commit_interval) { int? | float? }
        required(:offset_commit_threshold).filled(:int?)
        required(:offset_retention_time).maybe(:integer)
        required(:heartbeat_interval).filled { (int? | float?) & gteq?(0) }
        required(:fetcher_max_queue_size).filled(:int?, gt?: 0)
        required(:rebalance_timeout).filled(:int?, gt?: 0)
        required(:assignment_strategy).value(:any)
        required(:connect_timeout).filled { (int? | float?) & gt?(0) }
        required(:reconnect_timeout).filled { (int? | float?) & gteq?(0) }
        required(:socket_timeout).filled { (int? | float?) & gt?(0) }
        required(:min_bytes).filled(:int?, gt?: 0)
        required(:max_bytes).filled(:int?, gt?: 0)
        required(:max_wait_time).filled { (int? | float?) & gteq?(0) }
        required(:batch_fetching).filled(:bool?)

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

        optional(:ssl_verify_hostname).maybe(:bool?)
        optional(:ssl_ca_certs_from_system).maybe(:bool?)
        optional(:sasl_over_ssl).maybe(:bool?)
        optional(:sasl_oauth_token_provider).value(:any)

        # It's not with other encryptions as it has some more rules
        optional(:sasl_scram_mechanism)
          .maybe(:str?, included_in?: SASL_SCRAM_MECHANISMS)
      end

      # Uri rule to check if uri is in a Karafka acceptable format
      rule(:seed_brokers) do
        if value.is_a?(Array) && !value.all?(&method(:kafka_uri?))
          key.failure(:invalid_broker_schema)
        end
      end

      rule(:topics) do
        if value.is_a?(Array)
          names = value.map { |topic| topic[:name] }

          key.failure(:topics_names_not_unique) if names.size != names.uniq.size
        end
      end

      rule(:topics) do
        if value.is_a?(Array)
          value.each_with_index do |topic, index|
            TOPIC_CONTRACT.call(topic).errors.each do |error|
              key([:topics, index, error.path[0]]).failure(error.text)
            end
          end
        end
      end

      rule(:assignment_strategy) do
        key.failure(:does_not_respond_to_call) unless value.respond_to?(:call)
      end

      rule(:ssl_client_cert, :ssl_client_cert_key) do
        if values[:ssl_client_cert] && !values[:ssl_client_cert_key]
          key(:ssl_client_cert_key).failure(:ssl_client_cert_with_ssl_client_cert_key)
        end
      end

      rule(:ssl_client_cert, :ssl_client_cert_key) do
        if values[:ssl_client_cert_key] && !values[:ssl_client_cert]
          key(:ssl_client_cert).failure(:ssl_client_cert_key_with_ssl_client_cert)
        end
      end

      rule(:ssl_client_cert, :ssl_client_cert_chain) do
        if values[:ssl_client_cert_chain] && !values[:ssl_client_cert]
          key(:ssl_client_cert).failure(:ssl_client_cert_chain_with_ssl_client_cert)
        end
      end

      rule(:ssl_client_cert_chain, :ssl_client_cert_key) do
        if values[:ssl_client_cert_chain] && !values[:ssl_client_cert]
          key(:ssl_client_cert).failure(:ssl_client_cert_chain_with_ssl_client_cert_key)
        end
      end

      rule(:ssl_client_cert_key_password, :ssl_client_cert_key) do
        if values[:ssl_client_cert_key_password] && !values[:ssl_client_cert_key]
          key(:ssl_client_cert_key).failure(:ssl_client_cert_key_password_with_ssl_client_cert_key)
        end
      end

      rule(:ssl_ca_cert) do
        key.failure(:invalid_certificate) if value && !valid_certificate?(value)
      end

      rule(:ssl_client_cert) do
        key.failure(:invalid_certificate) if value && !valid_certificate?(value)
      end

      rule(:ssl_ca_cert_file_path) do
        if value
          if File.exist?(value)
            key.failure(:invalid_certificate_from_path) unless valid_certificate?(File.read(value))
          else
            key.failure(:does_not_exist)
          end
        end
      end

      rule(:ssl_client_cert_key) do
        key.failure(:invalid_private_key) if value && !valid_private_key?(value)
      end

      rule(:ssl_client_cert_chain) do
        key.failure(:invalid_certificate) if value && !valid_certificate?(value)
      end

      rule(:sasl_oauth_token_provider) do
        key.failure(:does_not_respond_to_token) if value && !value.respond_to?(:token)
      end

      rule(:max_wait_time, :socket_timeout) do
        max_wait_time = values[:max_wait_time]
        socket_timeout = values[:socket_timeout]

        if socket_timeout.is_a?(Numeric) &&
           max_wait_time.is_a?(Numeric) &&
           max_wait_time > socket_timeout

          key(:max_wait_time).failure(:max_wait_time_limit)
        end
      end

      rule(:pause_timeout, :pause_max_timeout, :pause_exponential_backoff) do
        if values[:pause_exponential_backoff]
          if values[:pause_timeout].to_i > values[:pause_max_timeout].to_i
            key(:pause_max_timeout).failure(:max_timeout_size_for_exponential)
          end
        end
      end

      private

      # @param value [String] potential RSA key value
      # @return [Boolean] is the given string a valid RSA key
      def valid_private_key?(value)
        OpenSSL::PKey.read(value)
        true
      rescue OpenSSL::PKey::PKeyError
        false
      end

      # @param value [String] potential X509 cert value
      # @return [Boolean] is the given string a valid X509 cert
      def valid_certificate?(value)
        OpenSSL::X509::Certificate.new(value)
        true
      rescue OpenSSL::X509::CertificateError
        false
      end

      # @param value [String] potential kafka uri
      # @return [Boolean] true if it is a kafka uri, otherwise false
      def kafka_uri?(value)
        uri = URI.parse(value)
        URI_SCHEMES.include?(uri.scheme) && uri.port
      rescue URI::InvalidURIError
        false
      end
    end
  end
end
