# frozen_string_literal: true

module Karafka
  # Namespace for all the validation schemas that we use to check input
  module Schemas
    # Regexp for validating format of groups and topics
    # @note It is not nested inside of the schema, as it is used by couple schemas
    TOPIC_REGEXP = /\A(\w|\-|\.)+\z/.freeze

    # Frozen array for internal usage
    EMPTY_ARRAY = [].freeze
  end
end
