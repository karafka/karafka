module Karafka
  # Namespace used to encapsulate all the internal errors of Karafka
  module Errors
    # Base class for all the Karafka internal errors
    class BaseError < StandardError; end

    # Raised when router receives topic name which is not provided for any of
    #  controllers(inherited from Karafka::BaseController)
    # This should never happen because we listed only to topics defined in controllers
    # but theory is not always right. If you encounter this error - please contact
    # Karafka maintainers
    class NonMatchingTopicError < BaseError; end

    # Raised when we have a controller that does not have a perform method that is required
    class PerformMethodNotDefined < BaseError; end

    # Raised when we have few controllers(inherited from Karafka::BaseController)
    #   with the same group name
    class DuplicatedGroupError < BaseError; end

    # Raised when we have few controllers(inherited from Karafka::BaseController)
    #   with the same topic name
    class DuplicatedTopicError < BaseError; end
  end
end
