# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Deserializers < Base
        # Namespace for this feature's share-group routing hooks.
        module ShareGroups
          # Deserializers apply identically to share-group topics - share groups process message
          # payloads, keys and headers just like consumer groups. Reuses the consumer-group `Topic`
          # module so it is prepended onto the share topic class as well.
          Topic = ConsumerGroups::Topic
        end
      end
    end
  end
end
