# frozen_string_literal: true

module Karafka
  module Pro
    # Pro routing components
    module Routing
      # Routing extensions that allow to configure some extra PRO routing options
      module Extensions
        class << self
          # @param base [Class] class we extend
          def included(base)
            base.attr_accessor :long_running_job
          end
        end

        # @return [Boolean] is a given job on a topic a long running one
        def long_running_job?
          @long_running_job || false
        end
      end
    end
  end
end
