module Karafka
  module Aspects
    class BaseAspect < ::Aspector::Base
      default private_methods: true

      def handle(this, options, args, message, *result)
        formatter = Formatter.new(options, args, instance_run(this, result, message))

        Event.new(options[:topic], formatter.message).send!
      end

      private

      def instance_run(this, result, message)
        return this.instance_eval(&message) if message.parameters.empty?

        this.instance_exec(result, message) { |res, block| block.call(res.first) }
      end
    end
  end
end
