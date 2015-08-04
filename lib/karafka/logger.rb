module Karafka
  # Default logger for Event Delegator
  # @note It uses ::Logger features - providing basic logging
  class Logger < Logger
    # @param context [String, Class] IO class or logfile string path
    # @return [Karafka::Logger] Karafka logger instance
    # @example Creating a new logger
    # Karafka::Logger.new(STDOUT)
    # Karafka::Logger.new('logfile.log')
    def initialize(context)
      super(context)
      @level = (ENV['EVENT_DELEGATOR_LOG_LEVEL'] || ::Logger::ERROR).to_i
    end

    %i( debug info warn error fatal ).each do |level|
      define_method level do |arg, &block|
        super(nil) { format(arg, block.call) }
      end
    end

    private

    # Formats logger message
    def format(arg, options)
      msg = [arg]
      msg += options
      msg.join(' | ')
    end
  end

  # Null object for logger
  # Is used when logger is not defined
  class NullLogger
    # Returns nil for any method call
    def self.method_missing(*_args, &_block)
      nil
    end
  end
end
