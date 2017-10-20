# frozen_string_literal: true

module Karafka
  module Patches
    module RubyKafka
      # This patch allows us to inject business logic in between fetches and before the consumer
      # stop, so we can perform shutdown commit or anything else that we need since
      # ruby-kafka fetch loop does not allow that directly
      # We don't wan't to use poll ruby-kafka api as it brings many more problems that we would
      # have to take care of. That way, nothing like that ever happens but we get the control
      # over the stopping process that we need (since we're the once that initiate it for each
      # thread)
      def consumer_loop
        super do
          if Karafka::App.stopped?
            Karafka::Persistence::MessagesConsumer.read.stop
          else
            yield
          end
        end
      end
    end
  end
end
