# frozen_string_literal: true

module Karafka
  module Processing
    # Namespace for all the jobs that are suppose to run in workers
    module Jobs
      class Base
        attr_reader :executor
      end
    end
  end
end
