module Karafka
  module Aspects
    # Before method execution aspect
    # @example Apply before aspect to a method
    #   WaterDrop::Aspects::BeforeAspect.apply(
    #     ClassName,
    #     method: :run,
    #     topic: 'karafka_topic',
    #     message: -> { any_class_name_instance_method }
    #   )
    class BeforeAspect < BaseAspect
      before options[:method], interception_arg: true do |interception, *args|
        options = interception.options
        interception.aspect.handle(self, options, args, options[:message])
      end
    end
  end
end
