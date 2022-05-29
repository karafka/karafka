# frozen_string_literal: true

module Karafka
  module Helpers
    module Async
      # Allows a given class to run async in a separate thread. Provides also few methods we may
      # want to use to control the underlying thread
      class << self
        def included(base)
          base.extend ::Forwardable

          base.def_delegators :@thread, :join, :terminate, :alive?
        end
      end

      # Runs the `#call` method in a new thread
      def async_call
        @thread = Thread.new do
          Thread.current.abort_on_exception = true

          call
        end
      end
    end
  end
end
