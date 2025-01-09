# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
