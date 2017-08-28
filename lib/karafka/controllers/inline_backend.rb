# frozen_string_literal: true

module Karafka
  module Controllers
    # Backend that just runs stuff asap without any scheduling
    module InlineBackend
      private

      # Executes perform code immediately (without enqueuing)
      # @note Despite the fact, that workers won't be used, we still initialize all the
      #   classes and other framework elements
      def process
        Karafka.monitor.notice(self.class, params_batch)
        perform
      end
    end
  end
end
