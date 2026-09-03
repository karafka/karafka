# frozen_string_literal: true

module Karafka
  module Routing
    class Topics
      # Consumer-group topic. This is the canonical consumer-group topic class and the one that
      # consumer-group routing features are prepended onto (see
      # {Karafka::Routing::Features::Base.activate}).
      #
      # It is also reachable via the legacy flat {Karafka::Routing::Topic} alias, which is kept for
      # backwards compatibility (routing features attach to it by that name too) and is scheduled
      # for retirement in Karafka 3.0.
      class ConsumerTopic < Base
      end
    end
  end
end
