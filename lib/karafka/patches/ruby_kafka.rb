# frozen_string_literal: true

module Karafka
  module Patches
    # Patches for Ruby Kafka gem
    module RubyKafka
      # This patch allows us to inject business logic in between fetches and before the consumer
      # stop, so we can perform stop commit or anything else that we need since
      # ruby-kafka fetch loop does not allow that directly
      # We don't won't to use poll ruby-kafka api as it brings many more problems that we would
      # have to take care of. That way, nothing like that ever happens but we get the control
      # over the stopping process that we need (since we're the once that initiate it for each
      # thread)
      def consumer_loop
        super do
          consumers = Karafka::Persistence::Consumers
                      .current
                      .values
                      .flat_map(&:values)
                      .select { |consumer| consumer.class.respond_to?(:after_fetch) }

          if Karafka::App.stopping?
            publish_event(consumers, 'before_stop')
            Karafka::Persistence::Client.read.stop
          else
            publish_event(consumers, 'before_poll')
            yield
            publish_event(consumers, 'after_poll')
          end
        end
      end

      private

      # Notifies consumers about particular events happening
      # @param consumers [Array<Object>] all consumers that want to be notified about an event
      # @param event_name [String] name of the event that happened
      def publish_event(consumers, event_name)
        consumers.each do |consumer|
          key = "consumers.#{Helpers::Inflector.map(consumer.class.to_s)}.#{event_name}"
          Karafka::App.monitor.instrument(key, context: consumer)
        end
      end
    end
  end
end
