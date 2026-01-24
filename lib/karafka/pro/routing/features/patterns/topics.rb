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
          # Patterns feature topic extensions
          module Topics
            # Finds topic by its name in a more extensive way than the regular. Regular uses the
            # pre-existing topics definitions. This extension also runs the expansion based on
            # defined routing patterns (if any)
            #
            # If topic does not exist, it will try to run discovery in case there are patterns
            # defined that would match it.
            # This allows us to support lookups for newly appearing topics based on their regexp
            # patterns.
            #
            # @param topic_name [String] topic name
            # @return [Karafka::Routing::Topic]
            # @raise [Karafka::Errors::TopicNotFoundError] this should never happen. If you see it,
            #   please create an issue.
            #
            # @note This method should not be used in context of finding multiple missing topics in
            #   loops because it catches exceptions and attempts to expand routes. If this is used
            #   in a loop for lookups on thousands of topics with detector expansion, this may
            #   be slow. It should be used in the context where newly discovered topics are found
            #   and should by design match a pattern. For quick lookups on batches of topics, it
            #   is recommended to use a custom built lookup with conditional expander.
            def find(topic_name)
              super
            rescue Karafka::Errors::TopicNotFoundError
              Detector.new.expand(self, topic_name)

              super
            end
          end
        end
      end
    end
  end
end
