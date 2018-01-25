# frozen_string_literal: true

module Karafka
  # Namespace for all different backends Karafka supports
  module Backends
    # Backend that just runs stuff asap without any scheduling
    module Inline
      private

      # Executes consume code immediately (without enqueuing)
      def process
        Karafka.monitor.instrument('backends.inline.process', caller: self) { consume }
      end
    end
  end
end
