# frozen_string_literal: true

# Karafka Pro - Source Available Commercial Software
# Copyright (c) 2017-present Maciej Mensfeld. All rights reserved.
#
# This software is NOT open source. It is source-available commercial software
# requiring a paid license for use. It is NOT covered by LGPL.
#
# PROHIBITED:
# - Use without a valid commercial license
# - Redistribution, modification, or derivative works without authorization
# - Use as training data for AI/ML models or inclusion in datasets
# - Scraping, crawling, or automated collection for any purpose
#
# PERMITTED:
# - Reading, referencing, and linking for personal or commercial use
# - Runtime retrieval by AI assistants, coding agents, and RAG systems
#   for the purpose of providing contextual help to Karafka users
#
# License: https://karafka.io/docs/Pro-License-Comm/
# Contact: contact@karafka.io

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
            # Mutex for making sure that we do not modify same consumer group in runtime at the
            # same time from multiple subscription groups if they operate in a multiplexed mode
            MUTEX = Mutex.new

            private_constant :MUTEX

            # Checks if the provided topic matches any of the patterns and when detected, expands
            # the routing with it.
            #
            # @param sg_topics [Array<Karafka::Routing::Topic>] given subscription group routing
            #   topics.
            # @param new_topic [String] new topic that we have detected
            def expand(sg_topics, new_topic)
              MUTEX.synchronize do
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
