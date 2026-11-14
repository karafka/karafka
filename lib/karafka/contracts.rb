# frozen_string_literal: true

module Karafka
  # Namespace for all the validation contracts that we use to check input
  module Contracts
    # Regexp for validating format of group ids, client ids and topic name parts
    # @note It is not nested inside of the contracts, as it is used by couple of them
    TOPIC_REGEXP = /\A[A-Za-z0-9\-_.]+\z/

    # Regexp for validating topic names. On top of the format, Kafka rejects names longer than
    # 249 characters and the `.` and `..` names
    TOPIC_NAME_REGEXP = /\A(?!\.\.?\z)[A-Za-z0-9\-_.]{1,249}\z/
  end
end
