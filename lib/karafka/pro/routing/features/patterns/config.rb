# frozen_string_literal: true

# This code is part of Karafka Pro, a commercial component not licensed under LGPL.
# See LICENSE for details.

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
          Config = Struct.new(
            :active,
            :type,
            :pattern,
            keyword_init: true
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
