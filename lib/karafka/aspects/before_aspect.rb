module Karafka
  module Aspects
    class BeforeAspect < BaseAspect
      before options[:method], interception_arg: true do |interception, *args|
        options = interception.options
        interception.aspect.handle(self, options, args, options[:message])
      end
    end
  end
end
