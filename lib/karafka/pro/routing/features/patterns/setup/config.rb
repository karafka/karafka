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
        # Dynamic topics builder feature.
        # Allows you to define patterns in routes that would then automatically subscribe and
        # start consuming new topics
        #
        # This feature works by injecting a virtual topics and running blank subscriptions on
        # customers for future detection of topics that could be then subscribed on cluster
        # changes after the refreshes
        #
        # The cost of having this is that we run a blank consumer group client connection but
        # there is no other easy way at the moment.
        #
        # We inject a virtual topic to hold a connection but also to be able to run validations
        # during boot to ensure consistency of the pattern base setup
        class Patterns < Base
          # Setup namespace for patterns extensions
          module Setup
            # Config for patterns
            class Config
              extend ::Karafka::Core::Configurable

              # Run re-discovery at most once every five minutes. This is not cheap because it
              # creates a new admin librdkafka instance and lists all the topics, hence the limit
              setting(:ttl, default: 5 * 60 * 1_000)

              configure
            end
          end
        end
      end
    end
  end
end
