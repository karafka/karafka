# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Deserializers < Base
        # Deserializers apply identically to share-group topics - share groups process message
        # payloads, keys and headers just like consumer groups. Reuses the consumer-group `Topic`
        # module so it is prepended onto the share topic class as well.
        ShareTopic = Topic
      end
    end
  end
end
