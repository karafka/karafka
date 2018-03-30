# frozen_string_literal: true

module Karafka
  module Patches
    # Patches for Ruby Kafka gem
    module RubyKafka
      # This patch allows us to inject business logic in between fetches and before the consumer
      # stop, so we can perform stop commit or anything else that we need since
      # ruby-kafka fetch loop does not allow that directly
      # We don't wan't to use poll ruby-kafka api as it brings many more problems that we would
      # have to take care of. That way, nothing like that ever happens but we get the control
      # over the stopping process that we need (since we're the once that initiate it for each
      # thread)
      def consumer_loop
        super do
          consumers = Karafka::Persistence::Consumer
                      .all
                      .values
                      .flat_map(&:values)
                      .select { |consumer| consumer.respond_to?(:publish) }

          if Karafka::App.stopped?
            consumers.each { |consumer| consumer.publish('before_stop', context: consumer) }
            Karafka::Persistence::Client.read.stop
          else
            consumers.each { |consumer| consumer.publish('before_poll', context: consumer) }
            yield
            consumers.each { |consumer| consumer.publish('after_poll', context: consumer) }
          end
        end
      end
    end
  end
end
