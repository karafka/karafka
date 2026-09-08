# frozen_string_literal: true

module Karafka
  module Routing
    # Share-group routing types (KIP-932 / Queues for Kafka). Mode namespace, sibling of
    # {Routing::ConsumerGroups}.
    module ShareGroups
      # Object used to describe a single Kafka share group that is going to cooperatively consume
      # given topics.
      #
      # Share groups reuse the whole consumer-group routing machinery (subscription group building,
      # activity management, contracts). They differ only in the group type they report, the
      # activity-manager scope they filter under and the topic class they instantiate
      # ({ShareGroups::Topic}), which keeps share-group feature flow separate from consumer-group
      # feature flow. Also reachable via the legacy flat {Karafka::Routing::ShareGroup} alias
      # (retired in 3.0).
      #
      # @note The routing layer only describes share groups. Running them is not yet supported - the
      #   server raises when it detects a share group at boot until the share-group runtime lands.
      class Group < Groups::Base
        # @return [Symbol] group type
        def group_type
          :share
        end

        private

        # @return [Symbol] activity-manager scope share groups filter under
        def activity_scope
          :share_groups
        end

        # @return [Class] topic class used for share-group topics. It deliberately does not inherit
        #   consumer-group routing features so that share-group feature flow stays independent.
        def topic_class
          Topic
        end
      end
    end
  end
end
