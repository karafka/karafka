# frozen_string_literal: true

module Karafka
  module Contracts
    # Contract for single full route (consumer group + topics) validation.
    class ConsumerGroup < Dry::Validation::Contract
      config.messages.load_paths << File.join(Karafka.gem_root, 'config', 'errors.yml')

      # Internal contract for sub-validating topics schema
      TOPIC_CONTRACT = ConsumerGroupTopic.new.freeze

      private_constant :TOPIC_CONTRACT

      params do
        required(:deserializer).filled
        required(:id).filled(:str?, format?: Karafka::Contracts::TOPIC_REGEXP)
        required(:kafka).filled
        required(:manual_offset_management).filled(:bool?)
        required(:max_messages) { int? & gteq?(1) }
        required(:max_wait_time).filled { int? & gteq?(10) }
        required(:topics).value(:array, :filled?)
      end

      rule(:topics) do
        if value&.is_a?(Array)
          names = value.map { |topic| topic[:name] }

          key.failure(:topics_names_not_unique) if names.size != names.uniq.size
        end
      end

      rule(:topics) do
        if value&.is_a?(Array)
          value.each_with_index do |topic, index|
            TOPIC_CONTRACT.call(topic).errors.each do |error|
              key([:topics, index, error.path[0]]).failure(error.text)
            end
          end
        end
      end
    end
  end
end
