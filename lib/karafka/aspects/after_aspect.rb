module Karafka
  module Aspects
    class AfterAspect < BaseAspect
      after options[:method], interception_arg: true do |interception, result, *args|
        options = interception.options
        interception.aspect.handle(self, options, args, options[:message], result)
      end
    end
  end
end
