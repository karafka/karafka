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
            # @param topic_name [String] topic name
            # @return [Karafka::Routing::Topic]
            # @raise [Karafka::Errors::TopicNotFoundError] this should never happen. If you see it,
            #   please create an issue.
            def find(topic_name)
              attempt ||= 0
              attempt += 1

              super
            rescue Karafka::Errors::TopicNotFoundError
              Detector.instance.detect(topic_name)

              attempt > 1 ? raise : retry
            end
          end
        end
      end
    end
  end
end
