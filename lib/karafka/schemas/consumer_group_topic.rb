# frozen_string_literal: true

module Karafka
  module Schemas
    # Consumer group topic validation rules
    class ConsumerGroupTopic < Dry::Validation::Contract
      params do
        required(:id).filled(:str?, format?: Karafka::Schemas::TOPIC_REGEXP)
        required(:name).filled
        required(:backend).filled(included_in?: %i[inline sidekiq])
        required(:consumer).filled
        required(:deserializer).filled
        required(:max_bytes_per_partition).filled(:int?, gteq?: 0)
        required(:start_from_beginning).filled(:bool?)
        required(:batch_consuming).filled(:bool?)
      end

      rule(:name) do
        if value.is_a?(String)
          key(:name).failure(:invalid_format) unless value.match?(Karafka::Schemas::TOPIC_REGEXP)
        elsif !value.is_a?(::Regexp)
          key(:name).failure(:must_be_a_string_or_regexp)
        end
      end
    end
  end
end
