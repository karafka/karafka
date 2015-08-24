module Karafka
  # Class used to catch signals from ruby Signal class
  class Terminator
    attr_reader :terminated

    # Default list of signals which we want to catch
    DEFAULT_SIGNALS = %i(
      SIGINT
    )

    # Setting terminated flag as false
    # Setting instance variable signals from param or DEFAULT_SIGNALS
    # @param signals [Array<Symbol>] list of signals
    #   matching with Signal.list
    def initialize(signals = DEFAULT_SIGNALS)
      @terminated = false
      @signals = signals
    end

    # Method catch signals defined in @signals variable
    # @param [Block] block of code that we want to execute
    # and reset signals to default values [SIG_DFL]
    def catch_signals(&block)
      trap_signals
      block.call
      reset_signals
    end

    private

    # Trapping and ignoring all signals defined in @signals variable
    # Setting @terminated flag as true
    # Logging error
    def trap_signals
      @signals.each do |s|
        trap(s) do
          @terminated = true
          log_error(s)
        end
      end
    end

    # Logging into Karafka.logger error with signal code
    # @param [Symbol] signal name
    def log_error(signal)
      Thread.new do
        Karafka.logger.error("Terminating with signal #{signal}")
      end
    end

    # Reset signals from @signal variable into default value [SIG_DFL]
    def reset_signals
      @signals.each do |s|
        trap(s, :SIG_DFL)
      end
    end
  end
end
