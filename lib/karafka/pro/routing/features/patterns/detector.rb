# frozen_string_literal: true

# This Karafka component is a Pro component under a commercial license.
# This Karafka component is NOT licensed under LGPL.
#
# All of the commercial components are present in the lib/karafka/pro directory of this
# repository and their usage requires commercial license agreement.
#
# Karafka has also commercial-friendly license, commercial support and commercial components.
#
# By sending a pull request to the pro components, you are agreeing to transfer the copyright of
# your code to Maciej Mensfeld.

module Karafka
  module Pro
    module Routing
      module Features
        class Patterns < Base
          # Detects if a given topic matches any of the patterns and if so, injects it into the
          # given subscription group routing
          #
          # @note This is NOT thread-safe and should run in a thread-safe context that warranties
          #   that there won't be any race conditions
          class Detector
            # Checks if the provided topic matches any of the patterns and when detected, expands
            # the routing with it.
            #
            # @param sg_topics [Array<Karafka::Routing::Topic>] given subscription group routing
            #   topics.
            # @param new_topic [String] new topic that we have detected
            def expand(sg_topics, new_topic)
              sg_topics
                .map(&:patterns)
                .select(&:active?)
                .select(&:matcher?)
                .map(&:pattern)
                .then { |pts| pts.empty? ? return : pts }
                .then { |pts| Patterns.new(pts) }
                .find(new_topic)
                .then { |pattern| pattern || return }
                .then { |pattern| install(pattern, new_topic, sg_topics) }
            end

            private

            # Adds the discovered topic into the routing
            #
            # @param pattern [Karafka::Pro::Routing::Features::Patterns::Pattern] matched pattern
            # @param discovered_topic [String] topic that we discovered that should be part of the
            #   routing from now on.
            # @param sg_topics [Array<Karafka::Routing::Topic>]
            def install(pattern, discovered_topic, sg_topics)
              consumer_group = pattern.topic.consumer_group

              # Build new topic and register within the consumer group
              topic = consumer_group.public_send(:topic=, discovered_topic, &pattern.config)
              topic.patterns(active: true, type: :discovered)

              # Assign the appropriate subscription group to this topic
              topic.subscription_group = pattern.topic.subscription_group

              # Inject into subscription group topics array always, so everything is reflected
              # there but since it is not active, will not be picked
              sg_topics << topic
            end
          end
        end
      end
    end
  end
end
