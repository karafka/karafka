# frozen_string_literal: true

module Karafka
  module Processing
    # Namespace for all the jobs that are suppose to run in workers
    module Jobs
      class Base
        extend Forwardable

        def_delegators :executor, :group_id, :id

        attr_reader :executor
      end
    end
  end
end
