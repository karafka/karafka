# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    module Processing
      # Namespace for Pro coordinator related sub-components
      module Coordinators
        # Object used to track errors in between executions to be able to build error-type based
        # recovery flows.
        class ErrorsTracker
          include Enumerable

          # Max errors we keep in memory.
          # We do not want to keep more because for DLQ-less this would cause memory-leaks.
          STORAGE_LIMIT = 100

          private_constant :STORAGE_LIMIT

          def initialize
            @errors = []
          end

          # Clears all the errors
          def clear
            @errors.clear
          end

          # @param error [StandardError] adds the error to the tracker
          def <<(error)
            @errors.shift if @errors.size >= STORAGE_LIMIT
            @errors << error
          end

          # @return [Boolean] is the error tracker empty
          def empty?
            @errors.empty?
          end

          # @return [Integer] number of elements
          def size
            count
          end

          # @return [StandardError, nil] last error that occurred or nil if no errors
          def last
            @errors.last
          end

          # Iterates over errors
          # @param block [Proc] code we want to run on each error
          def each(&block)
            @errors.each(&block)
          end

          # @return [Array<StandardError>] array with all the errors that occurred
          def all
            @errors
          end
        end
      end
    end
  end
end
