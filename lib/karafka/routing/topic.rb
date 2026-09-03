# frozen_string_literal: true

module Karafka
  module Routing
    # Consumer-group topic. This is the canonical topic class and the one that consumer-group
    # routing features are prepended onto (see {Karafka::Routing::Features::Base.activate}).
    #
    # @note This is also reachable as {Karafka::Routing::Topics::ConsumerTopic}. The flat
    #   `Routing::Topic` constant is kept because it is widely referenced and is de-facto public
    #   API, and because routing features attach to it by name.
    class Topic < Topics::Base
    end
  end
end
