# frozen_string_literal: true

module Karafka
  module Routing
    module ConsumerGroups
      # Consumer-group topic. This is the canonical consumer-group topic class and the one that
      # consumer-group routing features are prepended onto (see
      # {Karafka::Routing::Features::Base.activate}).
      #
      # It is also reachable via the legacy flat {Karafka::Routing::Topic} alias, which is kept for
      # backwards compatibility (routing features attach to it by that name too) and is scheduled
      # for retirement in Karafka 3.0.
      #
      # @note The per-topic pause (backoff) configuration lives here rather than on
      #   {Topics::Base} because share groups (KIP-932) do not support pausing. See
      #   {Karafka::Routing::Features::ConsumerGroups::Pausing}.
      class Topic < Topics::Base
        # This method sets up the pause instance variable to nil before calling the parent class
        # initializer. The explicit initialization to nil is an optimization for Ruby's object
        # shapes system. The per-topic pause config itself is built lazily on first read,
        # defaulting to the global `config.pause.*` settings.
        def initialize(...)
          @pause = nil
          super
        end

        # @return [Karafka::Routing::Features::ConsumerGroups::Pausing::Config] per-topic pause
        #   configuration, reflecting the root `config.pause.*` settings.
        def pause
          @pause ||= Features::ConsumerGroups::Pausing::Config.new(
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
