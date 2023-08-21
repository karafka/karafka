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
          # Detects the new topics available to the routing with the once that are dynamically
          # recognized
          #
          # @note Works only on the primary cluster without option to run on other clusters
          #   If you are seeking this functionality please reach-out.
          #
          # @note This is NOT thread-safe and should run in a thread-safe context that warranties
          #   that there won't be any race conditions
          class Detector
            include ::Karafka::Core::Helpers::Time

            def initialize
              @last_checked = 0
              @usable = !::Karafka::App.consumer_groups.flat_map(&:patterns).empty?
              # `#float_now` operates in seconds
              @ttl = ::Karafka::App.config.patterns.ttl / 1_000.to_f
              @known_topics = []
            end

            # Looks for new topics matching patterns and if any, will add them to appropriate
            # subscription group and consumer group
            #
            # @note It uses ttl not to request topics with each poll
            def detect
              # Do nothing if there are no patterns
              return unless @usable
              return if (float_now - @last_checked) < @ttl

              available_topics = fetch_topics

              return if @known_topics == available_topics

              @known_topics = available_topics

              ::Karafka::App.consumer_groups.each do |consumer_group|
                topics = available_topics.dup

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

              @last_checked = float_now
            end

            private

            # @return [Array<String>] available topics in the cluster
            def fetch_topics
              ::Karafka::Admin
                .cluster_info
                .topics
                .map { |topic| topic.fetch(:topic_name) }
                .freeze
            # In case of any errors, we need to recover and continue because we do not want to
            # impact the runner (from which we run the detection via ticking) not to break the
            # whole process. There may be some temporary issues with the cluster and they should
            # not impact the stability of processing. The worse scenario is, that we will retry
            # next time
            #
            # We do not need any back-off or anything else because we run from ticks that also run
            # once in a while
            rescue StandardError => e
              Karafka.monitor.instrument(
                'error.occurred',
                caller: self,
                error: e,
                type: 'routing.features.patterns.detector.fetch_topics.error'
              )

              @known_topics
            end

            # Adds the discovered topic into the routing
            #
            # @param pattern [Karafka::Pro::Routing::Features::Patterns::Pattern] matched pattern
            # @param discovered_topic [String] topic that we discovered that should be part of the
            #   routing from now on.
            def install(pattern, discovered_topic)
              consumer_group = pattern.topic.consumer_group

              # Build new topic and register within the consumer group
              topic = consumer_group.public_send(:topic=, discovered_topic, &pattern.config)
              topic.patterns(active: true, type: :discovered)

              # Find matching subscription group
              subscription_group = consumer_group.subscription_groups.find do |subscription_group|
                subscription_group.name == topic.subscription_group
              end

              subscription_group || raise(StandardError)

              # Make sure, that we only clean on placeholder topics when we detected a topic that
              # is not excluded via the CLI. This is an edge case but can occur if someone defined
              # a pattern and defined that aside from that there should be explicit exclusions
              # via topics exclusion list. For example /.*/ (subscribe to all topics) plus
              # --exclude-topics xda (exclude this one special). The same applies to consumer and
              # subscription groups but in their case patterns are lower in the hierarchy, hence
              # patterns will be collectively excluded as their owning group won't be active
              # in case it is excluded
              #
              # We need to clean first before adding new topics because routing operations are not
              # in transactions. This means, that there could be a refresh of subscriptions
              # after removal of placeholder but before the new topic is added. This would mean
              # we would first trigger unsubscribe (which is expected) and only later the additive
              # subscribe on new. This is ok, but in case we would first add and then remove, we
              # could have a case where we would unsubscribe from a state that had all things
              # subscribed including the newly detected topic
              #
              # Unsubscribing can happen anyhow only in a case where we had no topics and the
              # placeholder one was running, so this should not be a problem (no real rebalance)
              if topic.active?
                # Deactivate the pattern one if present to avoid running a dummy subscription now
                # This is useful on boot where if topic is discovered, will basically replace the
                # placeholder one in place, effectively getting rid of the placeholder subscription
                subscription_group
                  .topics
                  .select { |topic| topic.patterns.placeholder? }
                  .each { |topic| topic.active(false) }

                consumer_group
                  .topics
                  .select { |topic| topic.patterns.placeholder? }
                  .each { |topic| topic.active(false) }
              end

              # Inject into subscription group topics array always, so everything is reflected
              # there but since it is not active, will not be picked
              subscription_group.topics << topic
            end
          end
        end
      end
    end
  end
end
