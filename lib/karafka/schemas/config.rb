# frozen_string_literal: true

module Karafka
  # Namespace for all the validation schemas that we use to check input
  module Schemas
    # Schema with validation rules for Karafka configuration details
    # @note There are many more configuration options inside of the
    #   Karafka::Setup::Config model, but we don't validate them here as they are
    #   validated per each route (topic + consumer_group) because they can be overwritten,
    #   so we validate all of that once all the routes are defined and ready
    Config = Dry::Validation.Schema do
      required(:name).filled(:str?, format?: /\A(\w|\-|\.)+\z/)

      required(:redis).maybe do
        schema do
          required(:url).filled(:str?)
        end
      end

      optional(:inline_mode).filled(:bool?)

      # If inline_mode is true, redis should be filled
      rule(redis_presence: %i[redis inline_mode]) do |redis, inline_mode|
        inline_mode.false?.then(redis.filled?)
      end

      optional(:connection_pool).schema do
        required(:size).filled
        optional(:timeout).filled(:int?)
      end
    end
  end
end
