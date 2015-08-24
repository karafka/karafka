module Karafka
  class Terminator
    class << self

      SIGNALS = %i(
        SIGINT
      )

      def catch_signals
        SIGNALS.each do |s|
          trap(s) do
            yield
          end
        end
      end

      def reset_signals
        SIGNALS.each do |s|
          trap(s, 'SIG_DFL')
        end
      end
    end
  end
end
