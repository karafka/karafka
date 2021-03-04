# frozen_string_literal: true

module Karafka
  module Contracts
    # Consumer group topic validation rules.
    class ConsumerGroupTopic < Dry::Validation::Contract
      params do
        required(:consumer).filled
        required(:deserializer).filled
        required(:id).filled(:str?, format?: Karafka::Contracts::TOPIC_REGEXP)
        required(:kafka).filled
        required(:manual_offset_management).filled(:bool?)
        required(:name).filled(:str?, format?: Karafka::Contracts::TOPIC_REGEXP)
      end
    end
  end
end
