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
        # Holds pattern info reference
        # Type is set to:
        #   `:regular` - in case patterns are not used and topic is just a regular existing topic
        #                matched directly based on the name
        #   `:discovered` - in case it is a real topic on which we started to listed
        #   `:matcher` - represents a regular expression used by librdkafka
        class Patterns < Base
          # Config for pattern based topic
          # Only pattern related topics are active in this context
          Config = Karafka::Routing::BaseConfig.define(
            :active,
            :type,
            :pattern
          ) do
            alias_method :active?, :active

            # @return [Boolean] is this a matcher topic
            def matcher?
              type == :matcher
            end

            # @return [Boolean] is this a discovered topic
            def discovered?
              type == :discovered
            end

            # @return [Boolean] is this a regular topic
            def regular?
              type == :regular
            end
          end
        end
      end
    end
  end
end
