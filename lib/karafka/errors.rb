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
    # This can only happen in a case when:
    #   - you've received a message and it was scheduled to Sidekiq background worker
    #   - you've changed the routing, so router can no longer associate your topic to
    #     any controller
    #   - or in a case when you do a lot of metaprogramming and you change routing/etc on runtime
    #
    # In case this happens, you will have to create a temporary route that will allow
    # you to "eat" everything from the Sidekiq queue.
    # @see https://github.com/karafka/karafka/issues/135
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

    # Raised when application does not have ApplicationWorker or other class that directly
    # inherits from Karafka::BaseWorker
    class BaseWorkerDescentantMissing < BaseError; end

    # Raised when we want to use #respond_with in controllers but we didn't define
    # (and we couldn't find) any appropriate responder for a given controller
    class ResponderMissing < BaseError; end

    # Raised when we want to use #respond_to in responders with a topic that we didn't register
    class UnregisteredTopic < BaseError; end

    # Raised when we send more than one message to a single topic but we didn't allow that when
    # we were registering topic in a responder
    class TopicMultipleUsage < BaseError; end

    # Raised when we didn't use a topic that was defined as non-optional (required)
    class UnusedResponderRequiredTopic < BaseError; end

    # Raised when configuration doesn't match with validation schema
    class InvalidConfiguration < BaseError; end
  end
end
