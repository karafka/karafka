# frozen_string_literal: true

module Karafka
  module Routing
    # Namespace for the Kafka-level group types (consumer groups and share groups).
    module Groups
      # Base class describing a single Kafka group (a consumer group or a share group) that is
      # going to subscribe to given topics. It carries the mode-agnostic routing machinery; the
      # subclasses only declare their {#group_type}, the activity-manager scope they filter under
      # and the topic class they instantiate.
      #
      # @note A single group represents one Kafka group, but it may not match 1:1 with subscription
      #   groups. There can be more subscription groups than groups.
      class Base
        include Helpers::ConfigImporter.new(
          activity_manager: %i[internal routing activity_manager],
          builder: %i[internal routing builder],
          subscription_groups_builder: %i[internal routing subscription_groups_builder]
        )

        attr_reader :id, :topics, :name

        # This is a "virtual" attribute that is not building subscription groups.
        # It allows us to store the "current" subscription group defined in the routing
        # This subscription group id is then injected into topics, so we can compute the subscription
        # groups
        attr_accessor :current_subscription_group_details

        # @param name [String, Symbol] name of this group.
        def initialize(name)
          @name = name.to_s
          # This used to be different when consumer mappers existed but now it is the same
          @id = @name
          @topics = Topics.new([])
          # Initialize the subscription group so there's always a value for it, since even if not
          # defined directly, a subscription group will be created
          @current_subscription_group_details = { name: SubscriptionGroup.id }
          # Track the base position for subscription groups to ensure stable positions when
          # rebuilding. This is critical for static group membership in swarm mode
          @subscription_groups_base_position = nil
        end

        # @return [Symbol] the type of this group. Overridden by subclasses (`:consumer`/`:share`).
        # @raise [NotImplementedError] when not overridden
        def group_type
          raise NotImplementedError, "Implement in a subclass"
        end

        # @return [Boolean] true when this is a consumer group
        def consumer_group?
          group_type == :consumer
        end

        # @return [Boolean] true when this is a share group
        def share_group?
          group_type == :share
        end

        # @return [Boolean] true if this group should be active in our current process
        def active?
          activity_manager.active?(activity_scope, name)
        end

        # Builds a topic representation inside of a current group route
        # @param name [String, Symbol] name of topic to which we want to subscribe
        # @return [Karafka::Routing::Topics::Base] newly built topic instance
        def topic=(name, &)
          # Clear memoized subscription groups since adding a topic requires rebuilding them
          # This is critical for group reopening across multiple draw calls
          @subscription_groups = nil

          topic = topic_class.new(name, self)
          @topics << Proxy.new(
            topic,
            builder.defaults,
            &
          ).target
          built_topic = @topics.last
          # We overwrite it conditionally in case it was not set by the user inline in the topic
          # block definition
          built_topic.subscription_group_details ||= current_subscription_group_details
          built_topic
        end

        # Assigns the current subscription group id based on the defined one and allows for further
        # topic definition
        # @param name [String, Symbol] name of the current subscription group
        def subscription_group=(name = SubscriptionGroup.id, &)
          # We cast it here, so the routing supports symbol based but that's anyhow later on
          # validated as a string
          @current_subscription_group_details = { name: name.to_s }

          Proxy.new(self, &)

          # We need to reset the current subscription group after it is used, so it won't leak
          # outside to other topics that would be defined without a defined subscription group
          @current_subscription_group_details = { name: SubscriptionGroup.id }
        end

        # @return [Array<Routing::SubscriptionGroup>] all the subscription groups build based on
        #   the group topics
        def subscription_groups
          @subscription_groups ||= begin
            result = subscription_groups_builder.call(
              topics,
              base_position: @subscription_groups_base_position
            )

            # Store the base position from the first subscription group for future rebuilds.
            # This ensures stable positions for static group membership.
            @subscription_groups_base_position ||= result.first&.position

            result
          end
        end

        # Hashed version of group that can be used for validation purposes
        # @return [Hash] hash with group attributes including serialized to hash
        #   topics inside of it.
        def to_h
          {
            topics: topics.map(&:to_h),
            id: id
          }.freeze
        end

        private

        # @return [Symbol] activity-manager scope this group filters under. Overridden by subclasses.
        # @raise [NotImplementedError] when not overridden
        def activity_scope
          raise NotImplementedError, "Implement in a subclass"
        end

        # @return [Class] routing topic class this group instantiates for its topics. Overridden
        #   by subclasses.
        # @raise [NotImplementedError] when not overridden
        def topic_class
          raise NotImplementedError, "Implement in a subclass"
        end
      end
    end
  end
end
