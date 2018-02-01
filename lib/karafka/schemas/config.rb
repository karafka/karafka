# frozen_string_literal: true

module Karafka
  # Namespace for all the validation schemas that we use to check input
  module Schemas
    # Regexp for validating format of groups and topics
    TOPIC_REGEXP = /\A(\w|\-|\.)+\z/

    # Schema with validation rules for Karafka configuration details
    # @note There are many more configuration options inside of the
    #   Karafka::Setup::Config model, but we don't validate them here as they are
    #   validated per each route (topic + consumer_group) because they can be overwritten,
    #   so we validate all of that once all the routes are defined and ready
    Config = Dry::Validation.Schema do
      required(:client_id).filled(:str?, format?: Karafka::Schemas::TOPIC_REGEXP)
      required(:shutdown_timeout) { none? | (int? & gteq?(0)) }
      required(:consumer_mapper)
      required(:topic_mapper)
      required(:params_base_class).filled

      optional(:backend).filled
    end
  end
end
