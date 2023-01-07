# frozen_string_literal: true

module Karafka
  module Helpers
    # Time related methods used across Karafka
    module Time
      # @return [Float] current monotonic time in milliseconds
      def monotonic_now
        ::Process.clock_gettime(::Process::CLOCK_MONOTONIC) * 1_000
      end

      # @return [Float] current time in float
      def float_now
        ::Time.now.utc.to_f
      end
    end
  end
end
