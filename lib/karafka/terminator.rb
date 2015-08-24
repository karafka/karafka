module Karafka
  # Class used to manage terminating signals from Ruby Signal class
  class Terminator
    # Default list of signals which we want to manage
    SIGNALS = %i(
      SIGINT
    )

    # Terminated flag
    attr_reader :terminated

    def initialize(signals = SIGNALS)
      @terminated = false
      @signals = signals
    end

    def catch_signals
      trap_signals
      yield
      reset_signals
    end

    def terminated?
      @terminated
    end

    private

    def trap_signals
      @signals.each do |s|
        trap(s) do
          Thread.new do
            Karafka.logger.error("Terminating with signal #{s}")
          end
          @terminated = true
        end
      end
    end

    # Reset signals from SIGNALS array
    #   into default value ('SIG_DFL')
    def reset_signals
      @signals.each do |s|
        trap(s, 'SIG_DFL')
      end
    end
  end
end
