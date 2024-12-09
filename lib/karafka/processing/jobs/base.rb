# frozen_string_literal: true

module Karafka
  module Processing
    # Namespace for all the jobs that are supposed to run in workers.
    module Jobs
      # Base class for all the jobs types that are suppose to run in workers threads.
      # Each job can have 3 main entry-points: `#before_call`, `#call` and `#after_call`
      # Only `#call` is required.
      class Base
        extend Forwardable

        # @note Since one job has always one executor, we use the jobs id and group id as reference
        def_delegators :executor, :id, :group_id

        attr_reader :executor

        class << self
          # @return [Symbol] Job matching appropriate action
          attr_accessor :action
        end

        # Creates a new job instance
        def initialize
          # All jobs are blocking by default and they can release the lock when blocking operations
          # are done (if needed)
          @non_blocking = false
          @status = :pending
        end

        # Runs the wrap/around job hook within which the rest of the flow happens
        # @param block [Proc] whole user related processing flow
        # @note We inject the action name so user can decide whether to run custom logic on a
        #   given action or not.
        def wrap(&block)
          executor.wrap(self.class.action, &block)
        end

        # When redefined can run any code prior to the job being scheduled
        # @note This will run in the listener thread and not in the worker
        def before_schedule
          raise NotImplementedError, 'Please implement in a subclass'
        end

        # When redefined can run any code that should run before executing the proper code
        def before_call; end

        # The main entry-point of a job
        def call
          raise NotImplementedError, 'Please implement in a subclass'
        end

        # When redefined can run any code that should run after executing the proper code
        def after_call; end

        # @return [Boolean] is this a non-blocking job
        #
        # @note Blocking job is a job, that will cause the job queue to wait until it is finished
        #   before removing the lock on new jobs being added
        #
        # @note All the jobs are blocking by default
        #
        # @note Job **needs** to mark itself as non-blocking only **after** it is done with all
        #   the blocking things (pausing partition, etc).
        def non_blocking?
          @non_blocking
        end

        # @return [Boolean] was this job finished.
        def finished?
          @status == :finished
        end

        # Marks the job as finished. Used by the worker to indicate, that this job is done.
        #
        # @note Since the scheduler knows exactly when it schedules jobs and when it keeps them
        #   pending, we do not need advanced state tracking and the only information from the
        #   "outside" is whether it was finished or not after it was scheduled for execution.
        def finish!
          @status = :finished
        end
      end
    end
  end
end
