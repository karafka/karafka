# frozen_string_literal: true

module Karafka
  module Routing
    module Groups
      # Object used to describe a single Kafka share group (KIP-932 / Queues for Kafka) that is
      # going to cooperatively consume given topics.
      #
      # @note Share groups reuse the whole consumer-group routing machinery (subscription group
      #   building, activity management, contracts). They differ only in the group type they report,
      #   the activity-manager scope they filter under and the topic class they instantiate
      #   ({Topics::ShareTopic}), which is what keeps share-group feature flow separate from
      #   consumer-group feature flow.
      #
      # @note The routing layer only *describes* share groups. Running them is not yet supported -
      #   the server raises when it detects a share group at boot until the share-group runtime
      #   lands. See the KIP-932 roadmap.
      class ShareGroup < Base
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
          Topics::ShareTopic
        end
      end
    end
  end
end
