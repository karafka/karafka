# frozen_string_literal: true

module Karafka
  module Routing
    class Topics
      # Namespaced alias for the canonical {Karafka::Routing::Topic}. Provided so the
      # `Topics::ConsumerTopic` / `Topics::ShareTopic` pair reads symmetrically (see issue #3130),
      # while keeping the flat `Routing::Topic` constant that routing features attach to and that
      # is widely referenced.
      ConsumerTopic = Karafka::Routing::Topic
    end
  end
end
