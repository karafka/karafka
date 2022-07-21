# frozen_string_literal: true

# This Karafka component is a Pro component.
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    # Pro routing components
    module Routing
      # Routing extensions that allow to configure some extra PRO routing options
      module TopicExtensions
        class << self
          # @param base [Class] class we extend
          def included(base)
            base.attr_accessor :long_running_job
            base.attr_accessor :virtual_partitioner
          end
        end

        # @return [Boolean] true if virtual partitioner is defined, false otherwise
        def virtual_partitioner?
          virtual_partitioner != nil
        end

        # @return [Boolean] is a given job on a topic a long running one
        def long_running_job?
          @long_running_job || false
        end
      end
    end
  end
end
