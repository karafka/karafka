# frozen_string_literal: true

module Karafka
  module Routing
    module ShareGroups
      # Share-group topic (KIP-932 / Queues for Kafka).
      #
      # It inherits only the mode-agnostic {Topics::Base} behavior and deliberately does **not**
      # inherit {ConsumerGroups::Topic}, so consumer-group routing features (which are prepended
      # onto the consumer topic) do not leak onto share topics. Share-group specific routing
      # features attach here (via a feature's `Features::ShareGroups::<Feature>::Topic` module)
      # once they land.
      #
      # @note The per-topic pause (backoff) configuration lives here, mirroring
      #   {ConsumerGroups::Topic}, so share and consumer topics expose it in the same format. See
      #   {Karafka::Routing::Features::ShareGroups::Pausing}.
      class Topic < Topics::Base
        # This method sets up the pause instance variable to nil before calling the parent class
        # initializer. The explicit initialization to nil is an optimization for Ruby's object
        # shapes system. The per-topic pause config itself is built lazily on first read,
        # defaulting to the global `config.pause.*` settings.
        def initialize(...)
          @pause = nil
          super
        end

        # @return [Karafka::Routing::Features::ShareGroups::Pausing::Config] per-topic pause
        #   configuration, reflecting the root `config.pause.*` settings.
        def pause
          @pause ||= Features::ShareGroups::Pausing::Config.new(
            active: false,
            timeout: Karafka::App.config.pause.timeout,
            max_timeout: Karafka::App.config.pause.max_timeout,
            with_exponential_backoff: Karafka::App.config.pause.with_exponential_backoff
          )
        end

        # @return [Hash] hash with all the topic attributes including the pause configuration
        def to_h
          super.merge(
            pause: pause.to_h
          ).freeze
        end
      end
    end
  end
end
