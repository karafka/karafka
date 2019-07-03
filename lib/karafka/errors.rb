# frozen_string_literal: true

module Karafka
  # Namespace used to encapsulate all the internal errors of Karafka
  module Errors
    # Base class for all the Karafka internal errors
    BaseError = Class.new(StandardError)

    # Should be raised when we have that that we cannot serialize
    SerializationError = Class.new(BaseError)

    # Should be raised when we tried to deserialize incoming data but we failed
    DeserializationError = Class.new(BaseError)

    # Raised when router receives topic name which does not correspond with any routes
    # This can only happen in a case when:
    #   - you've received a message and we cannot match it with a consumer
    #   - you've changed the routing, so router can no longer associate your topic to
    #     any consumer
    #   - or in a case when you do a lot of meta-programming and you change routing/etc on runtime
    #
    # In case this happens, you will have to create a temporary route that will allow
    # you to "eat" everything from the Sidekiq queue.
    # @see https://github.com/karafka/karafka/issues/135
    NonMatchingRouteError = Class.new(BaseError)

    # Raised when we don't use or use responder not in the way it expected to based on the
    # topics usage definitions
    InvalidResponderUsageError = Class.new(BaseError)

    # Raised when options that we provide to the responder to respond aren't what the contract
    # requires
    InvalidResponderMessageOptionsError = Class.new(BaseError)

    # Raised when configuration doesn't match with validation contract
    InvalidConfigurationError = Class.new(BaseError)

    # Raised when we try to use Karafka CLI commands (except install) without a boot file
    MissingBootFileError = Class.new(BaseError)

    # Raised when we want to read a persisted thread messages consumer but it is unavailable
    # This should never happen and if it does, please contact us
    MissingClientError = Class.new(BaseError)

    # Raised when want to hook up to an event that is not registered and supported
    UnregisteredMonitorEventError = Class.new(BaseError)

    # Raised when we've waited enough for shutting down a non-responsive process
    ForcefulShutdownError = Class.new(BaseError)
  end
end
