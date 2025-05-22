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
    MissingBootFileError = Class.new(BaseError) do
      # @param boot_file_path [Pathname] path where the boot file should be
      def initialize(boot_file_path)
        message = <<~MSG

          \e[31mKarafka Boot File Missing:\e[0m #{boot_file_path}

          Cannot find Karafka boot file - this file configures your Karafka application.

          \e[33mQuick fixes:\e[0m
            \e[32m1.\e[0m Navigate to your Karafka app directory
            \e[32m2.\e[0m Check if following file exists: \e[36m#{boot_file_path}\e[0m
            \e[32m3.\e[0m Install Karafka if needed: \e[36mkarafka install\e[0m

          \e[33mCommon causes:\e[0m
            \e[31m•\e[0m Wrong directory (not in Karafka app root)
            \e[31m•\e[0m File was accidentally moved or deleted
            \e[31m•\e[0m New project needing initialization

          For setup help: \e[34mhttps://karafka.io/docs/Getting-Started\e[0m
        MSG

        super(message)
        # In case of this error backtrace is irrelevant and we want to print comprehensive error
        # message without backtrace, this is why nullified.
        set_backtrace([])
      end
    end

    # Raised when we've waited enough for shutting down a non-responsive process
    ForcefulShutdownError = Class.new(BaseError)

    # Raised when the jobs queue receives a job that should not be received as it would cause
    # the processing to go out of sync. We should never process in parallel data from the same
    # topic partition (unless virtual partitions apply)
    JobsQueueSynchronizationError = Class.new(BaseError)

    # Raised when given topic is not found while expected
    TopicNotFoundError = Class.new(BaseError)

    # Raised when given consumer group is not found while expected
    ConsumerGroupNotFoundError = Class.new(BaseError)

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
    UnrecognizedCommandError = Class.new(BaseError) do
      # Overwritten not to print backtrace for unknown CLI command
      def initialize(*args)
        super
        set_backtrace([])
      end
    end

    # Raised when you were executing a command and it could not finish successfully because of
    # a setup state or parameters configuration
    CommandValidationError = Class.new(BaseError)

    # Raised when we attempt to perform operation that is only allowed inside of a transaction and
    # there is no transaction around us
    TransactionRequiredError = Class.new(BaseError)

    # Raised in case user would want to perform nested transactions.
    TransactionAlreadyInitializedError = Class.new(BaseError)

    # Raised when user used transactional offset marking but after that tried to use
    # non-transactional marking, effectively mixing both. This is not allowed.
    NonTransactionalMarkingAttemptError = Class.new(BaseError)

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
