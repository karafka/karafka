module Karafka
  # Namespace used to encapsulate all the internal errors of Karafka
  module Errors
    # Base class for all the Karafka internal errors
    class BaseError < StandardError; end

    # Should be raised when we attemp to parse incoming params but parsing fails
    #   If this error (or its descendant) is detected, we will pass the raw message
    #   into params and proceed further
    class ParserError < BaseError; end

    # Raised when router receives topic name which does not correspond with any routes
    #   This should never happen because we listed only to topics defined in routes
    #   but theory is not always right. If you encounter this error - please contact
    #   Karafka maintainers
    class NonMatchingRouteError < BaseError; end

    # Raised when we have few controllers(inherited from Karafka::BaseController)
    #   with the same group name
    class DuplicatedGroupError < BaseError; end

    # Raised when we have few controllers(inherited from Karafka::BaseController)
    #   with the same topic name
    class DuplicatedTopicError < BaseError; end

    # Raised when we want to use topic name that has unsupported characters
    class InvalidTopicName < BaseError; end

    # Raised when we want to use group name that has unsupported characters
    class InvalidGroupName < BaseError; end
  end
end
