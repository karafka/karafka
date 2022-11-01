# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      # This feature allows to continue processing when encountering errors.
      # After certain number of retries, given messages will be moved to alternative topic,
      # unclogging processing.
      #
      # @note This feature has an expanded version in the Pro mode. We do not use a new feature
      #   injection in Pro (topic settings)
      class DeadLetterQueue < Base
      end
    end
  end
end
