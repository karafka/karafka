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
                      .select { |ctrl| ctrl.respond_to?(:run_callbacks) }

          if Karafka::App.stopped?
            consumers.each { |ctrl| ctrl.run_callbacks :before_stop }
            Karafka::Persistence::Client.read.stop
          else
            consumers.each { |ctrl| ctrl.run_callbacks :before_poll }
            yield
            consumers.each { |ctrl| ctrl.run_callbacks :after_poll }
          end
        end
      end
    end
  end
end
