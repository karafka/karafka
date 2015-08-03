module Karafka
  module Aspects
    # Around method execution aspect
    # @example Apply around aspect to a method
    #   WaterDrop::Aspects::BeforeAspect.apply(
    #     ClassName,
    #     method: :run,
    #     topic: 'karafka_topic',
    #     before_message: -> { any_class_name_instance_method },
    #     after_message: ->(result) { "This is result of method run: #{result}" }
    #   )
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
