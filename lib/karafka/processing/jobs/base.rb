# frozen_string_literal: true

module Karafka
  module Processing
    # Namespace for all the jobs that are suppose to run in workers.
    module Jobs
      # Base class for all the jobs types that are suppose to run in workers threads.
      # Each job can have 3 main entry-points: `#prepare`, `#call` and `#teardown`
      # Only `#call` is required.
      class Base
        extend Forwardable

        # @note Since one job has always one executer, we use the jobs id and group id as reference
        def_delegators :executor, :id, :group_id

        attr_reader :executor

        # When redefined can run any code that should run before executing the proper code
        def prepare; end

        # When redefined can run any code that should run after executing the proper code
        def teardown; end

        # @return [Boolean] is this a non-blocking job
        # @note Blocking job is a job, that will cause the job queue to wait until it is finished
        #   before removing the lock on new jobs being added
        # @note All the jobs are blocking by default
        def non_blocking?
          false
        end
      end
    end
  end
end
