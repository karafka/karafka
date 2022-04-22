# frozen_string_literal: true

module Karafka
  module Contracts
    # Contract with validation rules for Karafka configuration details.
    #
    # @note There are many more configuration options inside of the
    #   `Karafka::Setup::Config` model, but we don't validate them here as they are
    #   validated per each route (topic + consumer_group) because they can be overwritten,
    #   so we validate all of that once all the routes are defined and ready.
    class Config < Base
      params do
        # License validity happens in the licenser. Here we do only the simple consistency checks
        required(:license).schema do
          required(:token) { bool? | str? }
          required(:entity) { str? }
          required(:expires_on) { date? }
        end

        required(:client_id).filled(:str?, format?: Karafka::Contracts::TOPIC_REGEXP)
        required(:concurrency) { int? & gt?(0) }
        required(:consumer_mapper).filled
        required(:consumer_persistence).filled(:bool?)
        required(:pause_timeout) { int? & gt?(0) }
        required(:pause_max_timeout) { int? & gt?(0) }
        required(:pause_with_exponential_backoff).filled(:bool?)
        required(:shutdown_timeout) { int? & gt?(0) }
        required(:kafka).filled(:hash)

        # We validate internals just to be sure, that they are present and working
        required(:internal).schema do
          required(:routing_builder)
          required(:status)
          required(:process)
          required(:scheduler)
          required(:subscription_groups_builder)
        end
      end

      # rdkafka requires all the keys to be strings, so we ensure that
      rule(:kafka) do
        next unless value.is_a?(Hash)

        value.each_key do |key|
          next if key.is_a?(Symbol)

          key(:"kafka.#{key}").failure(:kafka_key_must_be_a_symbol)
        end
      end

      rule(:pause_timeout, :pause_max_timeout) do
        if values[:pause_timeout].to_i > values[:pause_max_timeout].to_i
          key(:pause_timeout).failure(:max_timeout_vs_pause_max_timeout)
        end
      end
    end
  end
end
