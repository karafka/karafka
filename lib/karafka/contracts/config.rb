# frozen_string_literal: true

module Karafka
  module Contracts
    # Contract with validation rules for Karafka configuration details
    # @note There are many more configuration options inside of the
    #   Karafka::Setup::Config model, but we don't validate them here as they are
    #   validated per each route (topic + consumer_group) because they can be overwritten,
    #   so we validate all of that once all the routes are defined and ready
    class Config < Dry::Validation::Contract
      params do
        required(:client_id).filled(:str?, format?: Karafka::Contracts::TOPIC_REGEXP)
        required(:shutdown_timeout) { (int? & gt?(0)) }
        required(:consumer_mapper)
        required(:topic_mapper)

        optional(:backend).filled
      end
    end
  end
end
