# frozen_string_literal: true

module Karafka
  # Namespace for all the validation contracts that we use to check input
  module Contracts
    # Regexp for validating ids that are not full topic names: consumer and share group ids,
    # routing topic ids, the `client_id`, `group_id` and `admin.group_id` settings, and the Pro
    # recurring tasks `group_id` and scheduled messages `group_id` and `states_postfix`
    # @note It is not nested inside of the contracts, as it is used by couple of them
    KAFKA_IDS_REGEXP = /\A[A-Za-z0-9\-_.]+\z/

    # Regexp for validating topic names. On top of the `KAFKA_IDS_REGEXP` format, Kafka rejects
    # names longer than 249 characters and the `.` and `..` names
    TOPIC_NAME_REGEXP = /\A(?!\.\.?\z)[A-Za-z0-9\-_.]{1,249}\z/

    # Released karafka-web (1.0.1) reads this constant at load time, so it must stay until web
    # no longer uses it
    TOPIC_REGEXP = KAFKA_IDS_REGEXP
  end
end
