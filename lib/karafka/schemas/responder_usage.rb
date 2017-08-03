# frozen_string_literal: true

module Karafka
  module Schemas
    # Validator to check that everything in a responder flow matches responder rules
    ResponderUsage = Dry::Validation.Schema do
      configure do
        def self.messages
          super.merge(
            en: {
              errors: {
                used_topics_registration: 'all used topics must be registered'
              }
            }
          )
        end
      end

      required(:used_topics).maybe(:array?)
      required(:registered_topics).filled(:array?)

      validate(
        used_topics_registration: %i[used_topics registered_topics]
      ) do |used_topics, registered_topics|
        (used_topics - registered_topics).empty?
      end

      required(:topics).filled do
        each do
          schema do
            required(:name).filled(:str?, format?: Karafka::Schemas::TOPIC_REGEXP)
            required(:required).filled(:bool?)
            required(:multiple_usage).filled(:bool?)
            required(:usage_count).filled(:int?, gteq?: 0)

            rule(
              required_usage: %i[required usage_count]
            ) do |required, usage_count|
              required.true? > usage_count.gteq?(1)
            end

            rule(
              multiple_usage_permission: %i[multiple_usage usage_count]
            ) do |multiple_usage, usage_count|
              usage_count.gt?(1) > multiple_usage.true?
            end

            rule(
              multiple_usage_block: %i[multiple_usage usage_count]
            ) do |multiple_usage, usage_count|
              multiple_usage.false? > usage_count.lteq?(1)
            end
          end
        end
      end
    end
  end
end
