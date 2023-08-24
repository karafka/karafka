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
          # Patterns feature topic extensions
          module Topics
            # Finds topic by its name
            #
            # If topic does not exist, it will try to run discovery in case there are patterns
            # defined that would match it.
            # This allows us to support lookups for newly appearing topics based on their regexp
            # patterns.
            #
            # @param topic_name [String] topic name
            # @return [Karafka::Routing::Topic]
            # @raise [Karafka::Errors::TopicNotFoundError] This can happen only if you defined
            #   a pattern that would potentially contradict exclusions or in case the regular
            #   expression matching in librdkafka and Ruby itself would misalign.
            def find(topic_name)
              attempt ||= 0
              attempt += 1

              super
            rescue Karafka::Errors::TopicNotFoundError
              Detector.instance.expand(self, topic_name)

              attempt > 1 ? raise : retry
            end
          end
        end
      end
    end
  end
end
