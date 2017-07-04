# frozen_string_literal: true

module Karafka
  # Namespace for all the validation schemas that we use to check input
  module Schemas
    # Schema with validation rules for all configuration
    Config = Dry::Validation.Schema do
      required(:name).filled(:str?)
      required(:topic_mapper).filled
      optional(:inline_mode).filled(:bool?)

      required(:redis).maybe do
        schema do
          required(:url).filled(:str?)
        end
      end

      # If inline_mode is true, redis should be filled
      rule(redis_presence: %i[redis inline_mode]) do |redis, inline_mode|
        inline_mode.false?.then(redis.filled?)
      end

      optional(:batch_mode).filled(:bool?)
      optional(:start_from_beginning).filled(:bool?)

      optional(:connection_pool).schema do
        required(:size).filled
        optional(:timeout).filled(:int?)
      end

      required(:kafka).schema do
        required(:seed_brokers).filled(:array?)
        required(:session_timeout).filled(:int?)
        required(:offset_commit_interval).filled(:int?)
        required(:offset_commit_threshold).filled(:int?)
        required(:heartbeat_interval).filled(:int?)

        optional(:ssl_ca_cert).maybe(:str?)
        optional(:ssl_client_cert).maybe(:str?)
        optional(:ssl_client_cert_key).maybe(:str?)
      end
    end
  end
end
