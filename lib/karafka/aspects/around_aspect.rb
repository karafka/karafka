module Karafka
  module Aspects
    # Class for handling events around the method
    class AroundAspect < BaseAspect
      around options[:method], interception_arg: true do |interception, proxy, *args, &block|
        options = interception.options
        interception.aspect.handle(self, options, args, options[:before_message])
        result = proxy.call(*args, &block)
        interception.aspect.handle(self, options, args, options[:after_message], result)
      end
    end
  end
end
