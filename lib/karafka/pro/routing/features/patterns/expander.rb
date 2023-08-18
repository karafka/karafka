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
          # Expands the notion of topics available to the routing with the once that are
          # dynamically recognized
          #
          # @note Works only on the primary cluster without option to run on other clusters
          #   If you are seeking this functionality please reach-out.
          class Expander
            def inject
              ::Karafka::App.consumer_groups.each do |consumer_group|
                topics = available_topics

                # Remove topics that are already recognized
                consumer_group.topics.each do |topic|
                  topics.delete(topic)
                end

                # Take remaining topics and locate first matching (if any)
                topics.each do |available_topic|
                  pattern = consumer_group.patterns.find(available_topic)

                  # If there is no pattern we can use, we just move on
                  next unless pattern

                  # If there is a topic, we can use it and add it to the routing
                  install(pattern, available_topic)
                end
              end
            end

            private

            def available_topics
              @available_topics ||= ::Karafka::Admin
                                    .cluster_info
                                    .topics
                                    .map { |topic| topic.fetch(:topic_name) }
                                    .freeze

              # Make it non-destructive
              @available_topics.dup
            end

            def install(pattern, available_topic)
              consumer_group = pattern.topic.consumer_group

              # Build new topic and register within the consumer group
              topic = consumer_group.public_send(:topic=, available_topic, &pattern.config)
              topic.patterns(true, :discovered)

              # Find matching subscription group
              subscription_group = consumer_group.subscription_groups.find do |subscription_group|
                subscription_group.name == topic.subscription_group
              end

              subscription_group || raise(StandardError)

              # Inject into subscription group topics array
              subscription_group.topics << topic

              # Make sure, that we only clean on placeholder topics when we detected a topic that
              # is not excluded via the CLI. This is an edge case but can occur if someone defined
              # a pattern and defined that aside from that there should be explicit exclusions
              # via topics exclusion list. For example /.*/ (subscribe to all topics) plus
              # --exclude-topics xda (exclude this one special). The same applies to consumer and
              # subscription groups but in their case patterns are lower in the hierachy, hence
              # patterns will be collectively excluded as their owning group won't be active
              # in case it is excluded
              return unless topic.active?

              # Remove the pattern one if present to avoid running a dummy subscription now
              # This is useful on boot where if topic is discovered, will basically replace the
              # placeholder one in place, effectively getting rid of the placeholder subscription
              subscription_group.topics.delete_if { |topic| topic.patterns.placeholder? }
              consumer_group.topics.delete_if { |topic| topic.patterns.placeholder? }
            end
          end
        end
      end
    end
  end
end
