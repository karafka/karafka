# frozen_string_literal: true

module Karafka
  module Contracts
    # Consumer group topic validation rules.
    class ConsumerGroupTopic < Dry::Validation::Contract
      config.messages.load_paths << File.join(Karafka.gem_root, 'config', 'errors.yml')

      params do
        required(:consumer).filled
        required(:deserializer).filled
        required(:id).filled(:str?, format?: Karafka::Contracts::TOPIC_REGEXP)
        required(:kafka).filled
        required(:max_messages) { int? & gteq?(1) }
        required(:max_wait_time).filled { int? & gteq?(10) }
        required(:manual_offset_management).filled(:bool?)
        required(:name).filled(:str?, format?: Karafka::Contracts::TOPIC_REGEXP)
      end
    end
  end
end
