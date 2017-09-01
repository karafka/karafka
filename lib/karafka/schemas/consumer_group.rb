# frozen_string_literal: true

module Karafka
  module Schemas
    # Consumer group topic validation rules
    ConsumerGroupTopic = Dry::Validation.Schema do
      required(:id).filled(:str?, format?: Karafka::Schemas::TOPIC_REGEXP)
      required(:name).filled(:str?, format?: Karafka::Schemas::TOPIC_REGEXP)
      required(:backend).filled(included_in?: %i[inline sidekiq])
      required(:controller).filled
      required(:parser).filled
      required(:max_bytes_per_partition).filled(:int?, gteq?: 0)
      required(:start_from_beginning).filled(:bool?)
      required(:batch_processing).filled(:bool?)
      required(:persistent).filled(:bool?)
    end

    # Schema for single full route (consumer group + topics) validation.
    ConsumerGroup = Dry::Validation.Schema do
      required(:id).filled(:str?, format?: Karafka::Schemas::TOPIC_REGEXP)
      required(:seed_brokers).filled(:array?)
      required(:session_timeout).filled(:int?)
      required(:pause_timeout).filled(:int?, gteq?: 0)
      required(:offset_commit_interval).filled(:int?)
      required(:offset_commit_threshold).filled(:int?)
      required(:offset_retention_time) { none?.not > int? }
      required(:heartbeat_interval).filled(:int?, gteq?: 0)
      required(:connect_timeout).filled(:int?, gt?: 0)
      required(:socket_timeout).filled(:int?, gt?: 0)
      required(:max_wait_time).filled(:int?, gteq?: 0)
      required(:batch_consuming).filled(:bool?)
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
        sasl_plain_authzid
        sasl_plain_username
        sasl_plain_password
        sasl_gssapi_principal
        sasl_gssapi_keytab
      ].each do |encryption_attribute|
        optional(encryption_attribute).maybe(:str?)
      end
    end
  end
end
