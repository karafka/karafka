module Karafka
  module Aspects
    class Formatter
      def initialize(options, args, result)
        @options = options
        @args = args
        @result = result
      end

      def apply
        {
          topic:  @options[:topic],
          method: @options[:method],
          message: @result,
          args: @args
        }
      end
    end
  end
end
