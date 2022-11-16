# frozen_string_literal: true

module Karafka
  # Namespace used to encapsulate all the internal errors of Karafka
  module Errors
    # Base class for all the Karafka internal errors
    BaseError = Class.new(StandardError)

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

    # Raised when configuration doesn't match with validation contract
    InvalidConfigurationError = Class.new(BaseError)

    # Raised when we try to use Karafka CLI commands (except install) without a boot file
    MissingBootFileError = Class.new(BaseError)

    # Raised when we've waited enough for shutting down a non-responsive process
    ForcefulShutdownError = Class.new(BaseError)

    # Raised when the jobs queue receives a job that should not be received as it would cause
    # the processing to go out of sync. We should never process in parallel data from the same
    # topic partition (unless virtual partitions apply)
    JobsQueueSynchronizationError = Class.new(BaseError)

    # Raised when given topic is not found while expected
    TopicNotFoundError = Class.new(BaseError)

    # This should never happen. Please open an issue if it does.
    UnsupportedCaseError = Class.new(BaseError)

    # Raised when the license token is not valid
    InvalidLicenseTokenError = Class.new(BaseError)

    # This should never happen. Please open an issue if it does.
    InvalidCoordinatorStateError = Class.new(BaseError)

    # This should never happen. Please open an issue if it does.
    InvalidConsumerGroupStatusError = Class.new(BaseError)

    # This should never happen. Please open an issue if it does.
    StrategyNotFoundError = Class.new(BaseError)

    # This should never happen. Please open an issue if it does.
    SkipMessageNotFoundError = Class.new(BaseError)
  end
end
