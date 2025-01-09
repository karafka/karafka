# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
