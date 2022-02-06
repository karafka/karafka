# frozen_string_literal: true

module Karafka
  module Contracts
    # Contract for single full route (consumer group + topics) validation.
    class ConsumerGroup < Base
      # Internal contract for sub-validating topics schema
      TOPIC_CONTRACT = ConsumerGroupTopic.new.freeze

      private_constant :TOPIC_CONTRACT

      params do
        required(:id).filled(:str?, format?: Karafka::Contracts::TOPIC_REGEXP)
        required(:topics).value(:array, :filled?)
      end

      rule(:topics) do
        if value.is_a?(Array)
          names = value.map { |topic| topic[:name] }

          key.failure(:topics_names_not_unique) if names.size != names.uniq.size
        end
      end

      rule(:topics) do
        if value.is_a?(Array)
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
