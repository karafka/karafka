# frozen_string_literal: true

module Karafka
  module Processing
    # Namespace for all the jobs that are suppose to run in workers.
    module Jobs
      # Base class for all the jobs types that are suppose to run in workers threads.
      class Base
        extend Forwardable

        # @note Since one job has always one executer, we use the jobs id and group id as reference
        def_delegators :executor, :id, :group_id

        attr_reader :executor
      end
    end
  end
end
