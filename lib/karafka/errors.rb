# frozen_string_literal: true

module Karafka
  # Namespace used to encapsulate all the internal errors of Karafka
  module Errors
    # Base class for all the Karafka internal errors
    BaseError = Class.new(StandardError)

    # Should be raised when we attemp to parse incoming params but parsing fails
    #   If this error (or its descendant) is detected, we will pass the raw message
    #   into params and proceed further
    ParserError = Class.new(BaseError)

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
    NonMatchingRouteError = Class.new(BaseError)

    # Raised when application does not have ApplicationWorker or other class that directly
    # inherits from Karafka::BaseWorker
    BaseWorkerDescentantMissing = Class.new(BaseError)

    # Raised when we want to use #respond_with in controllers but we didn't define
    # (and we couldn't find) any appropriate responder for a given controller
    ResponderMissing = Class.new(BaseError)

    # Raised when we don't use or use responder not in the way it expected to based on the
    # topics usage definitions
    InvalidResponderUsage = Class.new(BaseError)

    # Raised when configuration doesn't match with validation schema
    InvalidConfiguration = Class.new(BaseError)

    # Raised when processing messages in batches but still want to use #params instead of
    # #params_batch
    ParamsMethodUnavailable = Class.new(BaseError)

    # Raised when for some reason we try to use invalid processing adapter and
    # we bypass validations
    InvalidProcessingAdapter = Class.new(BaseError)
  end
end
