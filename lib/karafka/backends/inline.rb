# frozen_string_literal: true

module Karafka
  # Namespace for all different backends Karafka supports
  module Backends
    # Backend that just runs stuff asap without any scheduling
    module Inline
      private

      # Executes perform code immediately (without enqueuing)
      def process
        Karafka.monitor.notice(self.class, params_batch)
        perform
      end
    end
  end
end
