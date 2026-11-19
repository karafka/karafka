# frozen_string_literal: true

module Karafka
  # Namespace for all the validation contracts that we use to check input
  module Contracts
    # Regexp for validating ids that are not full topic names: consumer and share group ids,
    # routing topic ids, the `client_id`, `group_id` and `admin.group_id` settings, and the Pro
    # recurring tasks `group_id` and scheduled messages `group_id` and `states_postfix`
    # @note It is not nested inside of the contracts, as it is used by couple of them
    NAME_REGEXP = /\A[A-Za-z0-9\-_.]+\z/

    # Regexp for validating topic names. On top of the `NAME_REGEXP` format, Kafka rejects names
    # longer than 249 characters and the `.` and `..` names
    TOPIC_NAME_REGEXP = /\A(?!\.\.?\z)[A-Za-z0-9\-_.]{1,249}\z/

    # @deprecated Use `NAME_REGEXP` or `TOPIC_NAME_REGEXP`. Will be removed in Karafka 2.7. Kept as
    #   the group id rule for external callers (karafka-web validates its `group_id` with it)
    TOPIC_REGEXP = NAME_REGEXP
  end
end
