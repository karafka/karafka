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
        class Pausing < Base
          # Expansion allowing for a per topic pause strategy definitions
          module Topic
            # Allows for per-topic pausing strategy setting
            #
            # @param timeout [Integer] how long should we wait upon processing error (milliseconds)
            # @param max_timeout [Integer] what is the max timeout in case of an exponential
            #   backoff (milliseconds)
            # @param with_exponential_backoff [Boolean] should we use exponential backoff
            #
            # @note We do not construct here the nested config like we do with other routing
            #   features, because this feature operates on the OSS layer by injection of values
            #   and a nested config is not needed.
            def pause(timeout: nil, max_timeout: nil, with_exponential_backoff: nil)
              self.pause_timeout = timeout if timeout
              self.pause_max_timeout = max_timeout if max_timeout

              return unless with_exponential_backoff

              self.pause_with_exponential_backoff = with_exponential_backoff
            end
          end
        end
      end
    end
  end
end
