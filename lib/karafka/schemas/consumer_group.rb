# frozen_string_literal: true

module Karafka
  module Schemas
    # Schema for single full route (consumer group + topics) validation.
    ConsumerGroup = Dry::Validation.Schema do
      # Valid uri schemas of Kafka broker url
      # The ||= is due to the behavior of require_all that resolves dependencies
      # but someetimes loads things twice
      URI_SCHEMES ||= %w[kafka kafka+ssl plaintext ssl].freeze

      # Available sasl scram mechanism of authentication (plus nil)
      SASL_SCRAM_MECHANISMS ||= %w[sha256 sha512].freeze

      configure do
        config.messages_file = File.join(
          Karafka.gem_root, 'config', 'errors.yml'
        )

        # Uri validator to check if uri is in a Karafka acceptable format
        # @param uri [String] uri we want to validate
        # @return [Boolean] true if it is a valid uri, otherwise false
        def broker_schema?(uri)
          uri = URI.parse(uri)
          URI_SCHEMES.include?(uri.scheme) && uri.port
        rescue URI::InvalidURIError
          false
        end
      end

      required(:id).filled(:str?, format?: Karafka::Schemas::TOPIC_REGEXP)
      required(:seed_brokers).filled { each(:broker_schema?) }
      required(:session_timeout).filled { int? | float? }
      required(:pause_timeout) { none? | ((int? | float?) & gteq?(0)) }
      required(:offset_commit_interval) { int? | float? }
      required(:offset_commit_threshold).filled(:int?)
      required(:offset_retention_time) { none?.not > int? }
      required(:heartbeat_interval).filled { (int? | float?) & gteq?(0) }
      required(:fetcher_max_queue_size).filled(:int?, gt?: 0)
      required(:connect_timeout).filled { (int? | float?) & gt?(0) }
      required(:socket_timeout).filled { (int? | float?) & gt?(0) }
      required(:min_bytes).filled(:int?, gt?: 0)
      required(:max_bytes).filled(:int?, gt?: 0)
      required(:max_wait_time).filled { (int? | float?) & gteq?(0) }
      required(:batch_fetching).filled(:bool?)
      required(:topics).filled { each { schema(ConsumerGroupTopic) } }

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

      # It's not with other encryptions as it has some more rules
      optional(:sasl_scram_mechanism)
        .maybe(:str?, included_in?: Karafka::Schemas::SASL_SCRAM_MECHANISMS)
    end
  end
end
