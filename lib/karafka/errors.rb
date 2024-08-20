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

    # Raised on attempt to deserializer a cleared message
    MessageClearedError = Class.new(BaseError)

    # This should never happen. Please open an issue if it does.
    InvalidCoordinatorStateError = Class.new(BaseError)

    # This should never happen. Please open an issue if it does.
    StrategyNotFoundError = Class.new(BaseError)

    # This should never happen. Please open an issue if it does.
    InvalidRealOffsetUsageError = Class.new(BaseError)

    # This should never happen. Please open an issue if it does.
    InvalidTimeBasedOffsetError = Class.new(BaseError)

    # For internal usage only
    # Raised when we run operations that require certain result but despite successfully finishing
    # it is not yet available due to some synchronization mechanisms and caches
    ResultNotVisibleError = Class.new(BaseError)

    # Raised when there is an attempt to run an unrecognized CLI command
    UnrecognizedCommandError = Class.new(BaseError)

    # Raised when we attempt to perform operation that is only allowed inside of a transaction and
    # there is no transaction around us
    TransactionRequiredError = Class.new(BaseError)

    # Raised in case user would want to perform nested transactions.
    TransactionAlreadyInitializedError = Class.new(BaseError)

    # Raised in case a listener that was paused is being resumed
    InvalidListenerResumeError = Class.new(BaseError)

    # Raised when we want to un-pause listener that was not paused
    InvalidListenerPauseError = Class.new(BaseError)

    # Raised in transactions when we attempt to store offset for a partition that we have lost
    # This does not affect producer only transactions, hence we raise it only on offset storage
    AssignmentLostError = Class.new(BaseError)

    # Raised if optional dependencies like karafka-web are required in a version that is not
    # supported by the current framework version or when an optional dependency is missing.
    #
    # Because we do not want to require web out of the box and we do not want to lock web with
    # karafka 1:1, we do such a sanity check. This also applies to cases where some external
    # optional dependencies are needed but not available.
    DependencyConstraintsError = Class.new(BaseError)

    # Raised when we were not able to open pidfd for given pid
    # This should not happen. If you see it, please report.
    PidfdOpenFailedError = Class.new(BaseError)

    # Failed to send signal to a process via pidfd
    # This should not happen. If you see it, please report.
    PidfdSignalFailedError = Class.new(BaseError)

    # Raised when given option/feature is not supported on a given platform or when given option
    # is not supported in a given configuration
    UnsupportedOptionError = Class.new(BaseError)
  end
end
