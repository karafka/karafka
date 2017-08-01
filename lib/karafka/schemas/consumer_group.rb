# frozen_string_literal: true

module Karafka
  module Schemas
    # Schema for single route validation.
    ConsumerGroup = Dry::Validation.Schema do
      required(:id).filled(:str?, format?: /\A(\w|\-|\.)+\z/)
      required(:seed_brokers).filled(:array?)
      required(:session_timeout).filled(:int?)
      required(:offset_commit_interval).filled(:int?)
      required(:offset_commit_threshold).filled(:int?)
      required(:heartbeat_interval).filled(:int?, gteq?: 0)
      required(:max_bytes_per_partition).filled(:int?, gteq?: 0)
      required(:start_from_beginning).filled(:bool?)
      required(:offset_retention_time) { none?.not > int? }
      required(:topic_mapper).filled

      optional(:batch_mode).filled(:bool?)
      optional(:ssl_ca_cert).maybe(:str?)
      optional(:ssl_client_cert).maybe(:str?)
      optional(:ssl_client_cert_key).maybe(:str?)
      optional(:sasl_gssapi_principal).maybe(:str?)
      optional(:sasl_gssapi_keytab).maybe(:str?)

      required(:topics).filled.each do
        schema do
          required(:id).filled(:str?, format?: /\A(\w|\-|\.)+\z/)
          required(:name).filled(:str?, format?: /\A(\w|\-|\.)+\z/)
          required(:inline_mode).filled(:bool?)
          required(:controller).filled
          required(:parser).filled
          required(:interchanger).filled
        end
      end
    end
  end
end
