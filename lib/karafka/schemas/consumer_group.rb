# frozen_string_literal: true

module Karafka
  module Schemas
    # Schema for single route validation.
    ConsumerGroup = Dry::Validation.Schema do
      required(:id).filled(:str?, format?: Karafka::Schemas::TOPIC_REGEXP)
      required(:seed_brokers).filled(:array?)
      required(:session_timeout).filled(:int?)
      required(:offset_commit_interval).filled(:int?)
      required(:offset_commit_threshold).filled(:int?)
      required(:offset_retention_time) { none?.not > int? }
      required(:heartbeat_interval).filled(:int?, gteq?: 0)
      required(:topic_mapper).filled
      required(:connect_timeout).filled(:int?, gt?: 0)
      required(:socket_timeout).filled(:int?, gt?: 0)
      required(:max_wait_time).filled(:int?, gteq?: 0)
      required(:batch_mode).filled(:bool?)

      # Max wait time cannot exceed socket_timeout - wouldn't make sense
      rule(
        max_wait_time_limit: %i[max_wait_time socket_timeout]
      ) do |max_wait_time, socket_timeout|
        socket_timeout.int? > max_wait_time.lteq?(value(:socket_timeout))
      end

      optional(:ssl_ca_cert).maybe(:str?)
      optional(:ssl_client_cert).maybe(:str?)
      optional(:ssl_client_cert_key).maybe(:str?)
      optional(:sasl_gssapi_principal).maybe(:str?)
      optional(:sasl_gssapi_keytab).maybe(:str?)

      required(:topics).filled do
        each do
          schema do
            required(:id).filled(:str?, format?: Karafka::Schemas::TOPIC_REGEXP)
            required(:name).filled(:str?, format?: Karafka::Schemas::TOPIC_REGEXP)
            required(:inline_mode).filled(:bool?)
            required(:controller).filled
            required(:parser).filled
            required(:interchanger).filled
            required(:max_bytes_per_partition).filled(:int?, gteq?: 0)
            required(:start_from_beginning).filled(:bool?)
          end
        end
      end
    end
  end
end
