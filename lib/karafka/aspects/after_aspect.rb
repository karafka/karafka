module Karafka
  module Aspects
    # Class for handling events after the method
    class AfterAspect < BaseAspect
      after options[:method], interception_arg: true do |interception, result, *args|
        options = interception.options
        interception.aspect.handle(self, options, args, options[:message], result)
      end
    end
  end
end
