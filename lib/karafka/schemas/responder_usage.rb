# frozen_string_literal: true

module Karafka
  module Schemas
    # Validator to check responder topic usage
    ResponderUsageTopic = Dry::Validation.Schema do
      required(:name).filled(:str?, format?: Karafka::Schemas::TOPIC_REGEXP)
      required(:required).filled(:bool?)
      required(:usage_count).filled(:int?, gteq?: 0)
      required(:registered).filled(eql?: true)
      required(:async).filled(:bool?)
      required(:serializer).filled

      rule(
        required_usage: %i[required usage_count]
      ) do |required, usage_count|
        required.true? > usage_count.gteq?(1)
      end
    end

    # Validator to check that everything in a responder flow matches responder rules
    ResponderUsage = Dry::Validation.Schema do
      required(:used_topics) { filled? > each { schema(ResponderUsageTopic) } }
      required(:registered_topics) { filled? > each { schema(ResponderUsageTopic) } }
    end
  end
end
