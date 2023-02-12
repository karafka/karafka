# frozen_string_literal: true

module Karafka
  # Namespace for all the validation contracts that we use to check input
  module Contracts
    # Regexp for validating format of groups and topics
    # @note It is not nested inside of the contracts, as it is used by couple of them
    TOPIC_REGEXP = /^[A-Za-z0-9\-_.]+$/
  end
end
