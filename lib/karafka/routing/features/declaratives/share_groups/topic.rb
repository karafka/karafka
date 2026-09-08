# frozen_string_literal: true

module Karafka
  module Routing
    module Features
      class Declaratives < Base
        # Namespace for this feature's share-group routing hooks.
        module ShareGroups
          # Declaratives apply identically to share-group topics - a topic's declarative structure
          # (partitions, replication factor, config) does not depend on whether it is consumed via
          # a consumer group or a share group. Reuses the consumer-group `Topic` module so it is
          # prepended onto the share topic class as well.
          Topic = ConsumerGroups::Topic
        end
      end
    end
  end
end
